#!/usr/bin/env ruby

module GClouder
  module Resources
    module Compute
      module VPNs
        include GClouder::GCloud
        include GClouder::Shell
        include GClouder::Logging
        include GClouder::Config::Project
        include GClouder::Config::CLIArgs
        include GClouder::Resource::Cleaner

        def self.header(stage = :ensure)
          info "[#{stage}] compute / vpns", indent: 1, title: true
        end

        def self.validate
          return if Local.list.empty?
          header :validate
          Local.validate
        end

        def self.dir
          cli_args[:keys_dir] || File.join(ENV["HOME"], "keys")
        end

        def self.ensure
          return if Local.list.empty?

          header

          Local.list.each do |region, instances|
            info region, indent: 2, heading: true
            info

            instances.each do |vpn|
              skip_vpn = false

              # if 'shared_secret' key is set, use it
              # if not, fall back to trying to read the secret from an environment variable, the name
              # of which is provided by the 'shared_secret_env_var' key
              unless vpn.key?("shared_secret") || vpn.key?("shared_secret_env_var") || vpn.key?("shared_secret_file")
                if cli_args[:dry_run]
                  warning "skipping resource since no shared secret found for VPN and this is a dry run"
                  skip_vpn = true
                else
                  fatal "shared_secret_env_var or shared_secret must be set for region/vpn: #{region}/#{vpn["name"]}"
                end
              end

              vpn["shared_secret"] = if vpn.key?("shared_secret") && !vpn["shared_secret"].empty? && !vpn["shared_secret"].nil?
                vpn["shared_secret"]
              else
                ENV[vpn["shared_secret_env_var"]] if vpn["shared_secret_env_var"]
              end

              # this overrides the above for now..
              if vpn.key?("shared_secret_file")
                config_file = File.join(dir, vpn["shared_secret_file"])

                if !File.exists?(config_file)
                  fatal "shared_secret_file specified for vpn but no file found for region/vpn: #{region}/#{vpn["name"]}"
                end

                vpn["shared_secret"] = File.read(config_file)
              end

              vpn.delete("shared_secret_env_var") if vpn.key?("shared_secret_env_var")
              vpn.delete("shared_secret_file") if vpn.key?("shared_secret_file")

              required_params = %w(peer_address shared_secret ike_version remote_traffic_selector
                                   local_traffic_selector target_vpn_gateway network)

              required_params.each do |param|
                fatal "no #{param} defined for region/vpn: #{region}/#{vpn}" unless vpn.key?(param)

                # FIXME: change once hashie has been ripped out
                if vpn[param].nil?
                  if cli_args[:dry_run]
                    warning "no #{param} defined for region/vpn: #{vpn["name"]} [#{region}]"
                    skip_vpn = true
                  else
                    fatal "no #{param} defined for region/vpn: #{vpn["name"]} [#{region}]"
                  end
                end

                if vpn[param].is_a?(String)
                  if cli_args[:dry_run]
                    warning "no #{param} defined for region/vpn: #{vpn["name"]} [#{region}]" if vpn[param].empty?
                    skip_vpn = true
                  else
                    fatal "no #{param} defined for region/vpn: #{vpn["name"]} [#{region}]" if vpn[param].empty?
                  end
                end
              end

              next if skip_vpn && !cli_args[:dry_run]

              VPN.create(region, vpn["name"], vpn)
            end
          end
        end

        module Local
          def self.section
            ["vpns"]
          end

          def self.list
            Resources::Region.instances(path: section).delete_if { |_k, v| v.empty? }
          end

          def self.validate
            Resources::Validate::Region.instances(
              list,
              required_keys:  GClouder::Config::Arguments.required(["compute", "vpn-tunnels"]),
              permitted_keys: GClouder::Config::Arguments.permitted(["compute", "vpn-tunnels"]),
              ignore_keys:    ["ike_version", "shared_secret_file", "network"]
            )
          end
        end

        module Remote
          def self.list
            Resources::Remote.instances(path: %w(compute vpn-tunnels))
          end
        end

        module VPN
          include GClouder::GCloud
          include GClouder::Shell
          include GClouder::Logging
          include GClouder::Helpers
          include GClouder::Config::CLIArgs

          def self.create(region, vpn, vpn_config)
            network = vpn_config['network']
            Resource.ensure :"compute target-vpn-gateways", vpn_config["target_vpn_gateway"],
                            "--network #{network} --region #{region}"

            vpn_config.delete("network")

            return if cli_args[:dry_run]

            ip_data = gcloud("--format json compute addresses describe vpn-#{vpn} --region=#{region}", force: true)

            unless ip_data.key?("address")
              fatal "could not find address for static ip with key: vpn-#{vpn} (is key allocated in project config?)"
            end

            address = ip_data["address"]

            Resource.ensure :"compute forwarding-rules",
                            "#{vpn}-esp",
                            "--region #{region} \
                            --ip-protocol ESP \
                            --address #{address} \
                            --target-vpn-gateway=#{vpn_config['target_vpn_gateway']}",
                            silent: true

            Resource.ensure :"compute forwarding-rules",
                            "#{vpn}-udp500",
                            "--region #{region} \
                            --ip-protocol UDP \
                            --ports 500 \
                            --address #{address} \
                            --target-vpn-gateway=#{vpn_config['target_vpn_gateway']}",
                            silent: true

            Resource.ensure :"compute forwarding-rules",
                            "#{vpn}-udp4500",
                            "--region #{region} --ip-protocol UDP --ports 4500 --address #{address} \
                            --target-vpn-gateway=#{vpn_config['target_vpn_gateway']}",
                            silent: true

            Resource.ensure :"compute vpn-tunnels", vpn,
                            "--region=#{region} #{hash_to_args(vpn_config)}",
                            silent: true

            vpn_config["remote_traffic_selector"].each_with_index do |range, index|
              Resource.ensure :"compute routes",
                              "route-#{vpn}-#{index}",
                              "--network=#{network} --next-hop-vpn-tunnel=#{vpn} \
                              --next-hop-vpn-tunnel-region=#{region} --destination-range=#{range}",
                              silent: true
            end

            GClouder::Resources::Compute::FirewallRules::Rule.ensure("vpn-#{vpn}-icmp", {
              "network"       => network,
              "source-ranges" => vpn_config["remote_traffic_selector"],
              "allow"         => "icmp"
            }, silent: true)
          end
        end
      end
    end
  end
end
