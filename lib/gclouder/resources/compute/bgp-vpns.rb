#!/usr/bin/env ruby

module GClouder
  module Resources
    module Compute
      module BGPVPNs
        include GClouder::GCloud
        include GClouder::Shell
        include GClouder::Logging
        include GClouder::Config::Project
        include GClouder::Config::CLIArgs
        include GClouder::Resource::Cleaner

        module Cleaner
          def self.custom
            Proc.new do |local_resources, remote_resource|
              local_resources.select { |r| "bgp-vpn-#{r['name']}" == remote_resource }.length > 0
            end
          end
        end

        def self.header(stage = :ensure)
          info "[#{stage}] compute / bgp-vpns", indent: 1, title: true
        end

        def self.validate
          return if Local.list.empty?
          header :validate
          Local.validate
        end

        def self.ensure
          return if Local.list.empty?

          header

          Local.list.each do |region, instances|
            info region, indent: 2, heading: true

            instances.each do |vpn|
              set_shared_secret(region, vpn)
              info
              BGPVPN.create(region, vpn)
            end
          end
        end

        def self.dir
          cli_args[:keys_dir] || File.join(ENV["HOME"], "keys")
        end

        def self.set_shared_secret(region, vpn)
          # if 'shared_secret' key is set, use it
          # if not, fall back to trying to read the secret from an environment variable, the name
          # of which is provided by the 'shared_secret_env_var' key
          unless vpn.key?("shared_secret") || vpn.key?("shared_secret_env_var") || vpn.key?("shared_secret_file")
            if cli_args[:dry_run]
              warning "no shared secret found for VPN"
            else
              fatal "shared_secret_env_var or shared_secret must be set for region/vpn: #{region}/#{vpn["name"]}"
              return false
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
        end

        module Local
          def self.list
            Resources::Region.instances(
              path: %w{bgp-vpns}
            ).delete_if { |_k, v| v.empty? }
          end

          def self.validate
            # FIXME: better validation
            Resources::Validate::Region.instances(
              list,
              required_keys:  GClouder::Config::Arguments.required(["compute", "vpn-tunnels"]),
              permitted_keys: GClouder::Config::Arguments.permitted(["compute", "vpn-tunnels"]),
              ignore_keys:    ["ike_version", "shared_secret", "address", "target_vpn_gateway", "bgp", "shared_secret_file", "network"]
            )
          end
        end

        module Remote
          def self.list
            # FIXME: should we be listing tunnels or gateways?
            Resources::Remote.instances(path: %w(compute target-vpn-gateways))
          end
        end

        module BGPVPN
          include GClouder::GCloud
          include GClouder::Shell
          include GClouder::Logging
          include GClouder::Helpers
          include GClouder::Config::CLIArgs

          def self.vpn_address(region, vpn)
            response = gcloud("--format json compute addresses describe #{vpn['address']} --region=#{region}", force: true)

            unless response.key?("address")
              fatal "could not find address for static ip with key: #{vpn['address']} (is key allocated in project config?)"
            end

            response["address"]
          end

          def self.create(region, vpn)
            network = vpn['network']

            info "#{vpn['name']} (bgp-vpn-#{vpn['name']})", indent: 3

            # check to see if router exists, if it doesn't then assume we need to create interface and bgp peer
            configure_router = !Resource.resource?("compute routers", "bgp-vpn-#{vpn['name']}", silent: true)

            # router
            Resource.ensure :"compute routers",
                            "bgp-vpn-#{vpn['name']}",
                            "--region #{region} \
                            --network #{network} \
                            --asn #{vpn['bgp']['local_asn']}",
                            extra_info: "(router)",
                            indent: 4

            # VPN gateway
            Resource.ensure :"compute target-vpn-gateways",
                            "bgp-vpn-#{vpn["name"]}",
                            "--network #{network} \
                            --region #{region}",
                            extra_info: "(gateway)",
                            indent: 4

            address = cli_args[:dry_run] ? "<automatic>" : vpn_address(region, vpn)

            # forwarding rules
            Resource.ensure :"compute forwarding-rules",
                            "bgp-vpn-#{vpn['name']}-esp",
                            "--region #{region} \
                            --ip-protocol ESP \
                            --address #{address} \
                            --target-vpn-gateway bgp-vpn-#{vpn['name']}",
                            extra_info: "(forwarding-rule)",
                            indent: 4

            Resource.ensure :"compute forwarding-rules",
                            "bgp-vpn-#{vpn['name']}-udp500",
                            "--region #{region} \
                            --ip-protocol UDP \
                            --ports 500 \
                            --address #{address} \
                            --target-vpn-gateway bgp-vpn-#{vpn['name']}",
                            extra_info: "(forwarding-rule)",
                            indent: 4

            Resource.ensure :"compute forwarding-rules",
                            "bgp-vpn-#{vpn['name']}-udp4500",
                            "--region #{region} --ip-protocol UDP --ports 4500 --address #{address} \
                            --target-vpn-gateway bgp-vpn-#{vpn['name']}",
                            extra_info: "(forwarding-rule)",
                            indent: 4

            # tunnel
            Resource.ensure :"compute vpn-tunnels", "bgp-vpn-#{vpn['name']}",
                            "--region #{region} \
                            --peer-address #{vpn['peer_address']} \
                            --ike-version #{vpn['ike_version']} \
                            --router bgp-vpn-#{vpn['name']} \
                            --target-vpn-gateway bgp-vpn-#{vpn['name']} \
                            --shared-secret #{vpn['shared_secret']}",
                            extra_info: "(tunnel)",
                            indent: 4

            if configure_router
              # router interface
              gcloud("compute routers add-interface bgp-vpn-#{vpn['name']} \
                     --region #{region} \
                     --interface-name bgp-vpn-interface-#{vpn['name']} \
                     --vpn-tunnel bgp-vpn-#{vpn['name']} \
                     --mask-length #{vpn['bgp']['mask']} \
                     --ip-address #{vpn['bgp']['local_address']}",
                     failure: false)
              add "bgp-vpn-#{vpn['name']} (router interface)", indent: 4

              # bgp peer
              gcloud("compute routers add-bgp-peer bgp-vpn-#{vpn['name']} \
                     --region #{region} \
                     --interface bgp-vpn-interface-#{vpn['name']} \
                     --advertised-route-priority #{vpn['bgp']['priority']} \
                     --peer-asn #{vpn['bgp']['peer_asn']} \
                     --peer-ip-address #{vpn['bgp']['peer_address']} \
                     --peer-name #{vpn['name']}",
                     failure: false)
              add "bgp-vpn-#{vpn['name']} (bgp peer)", indent: 4
            else
              good "bgp-vpn-#{vpn['name']} (router interface)", indent: 4
              good "bgp-vpn-#{vpn['name']} (bgp peer)", indent: 4
            end
          end
        end
      end
    end
  end
end
