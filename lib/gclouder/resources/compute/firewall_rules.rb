#!/usr/bin/env ruby

module GClouder
  module Resources
    module Compute
      module FirewallRules
        include GClouder::Config::CLIArgs
        include GClouder::Logging
        include GClouder::GCloud
        include GClouder::Resource::Cleaner

        def self.header(stage = :ensure)
          info "[#{stage}] compute / firewall-rules", indent: 1, title: true
        end

        def self.ensure
          return if Local.list.empty?
          header
          Local.list.each do |region, rules|
            info region, heading: true, indent: 2
            info
            rules.each do |rule|
              Rule.ensure(rule["name"], rule)
            end
          end
        end

        def self.validate
          return if Local.list.empty?
          header :validate
          Local.validate
        end

        def self.check
        end

        module Local
          include GClouder::Config::Project
          include GClouder::Logging

          def self.validate
            info "global", heading: true, indent: 2
            Resources::Validate::Global.instances(
              list,
              required_keys:  GClouder::Config::Arguments.required(%w(compute firewall-rules)),
              permitted_keys: GClouder::Config::Arguments.permitted(%w(compute firewall-rules)),
              ignore_keys: ["internal-icmp"]
            )
          end

          def self.list
            Resources::Global.instances(path: %w(firewall rules))
          end
        end

        module Remote
          def self.list
            Resources::Remote.instances(
              path:           %w(compute firewall-rules),
              ignore_keys:    %w(self_link creation_timestamp id kind self_link),
              skip_instances: { "name" => /^default-.*|^gke-.*|^k8s-fw-.*/, "network" => /^default$/ }
            )
          end
        end

        module Rule
          include GClouder::Logging
          include GClouder::Helpers
          include GClouder::GCloud

          def self.ensure(rule, args = {}, silent: false)
            Resource.ensure :"compute firewall-rules", rule, hash_to_args(args), silent: silent
          end

          def self.purge(rule, silent: false)
            Resource.purge :"compute firewall-rules", rule, silent: silent
          end
        end
      end
    end
  end
end
