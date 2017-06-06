#!/usr/bin/env ruby

module GClouder
  module Resources
    module Compute
      module Networks
        module Subnets
          include GClouder::Config::CLIArgs
          include GClouder::Config::Project
          include GClouder::Logging
          include GClouder::Config::Arguments
          include GClouder::Resource::Cleaner

          def self.header(stage = :ensure)
            info "[#{stage}] compute / network / subnet", title: true
          end

          def self.validate
            return if Local.list.empty?
            header :validate
            Local.validate
          end

          def self.ensure
            return if Local.list.empty?
            header

            Local.list.each do |region, subnets|
              next if subnets.empty?
              info region, heading: true, indent: 2
              info
              subnets.each do |subnet|
                Subnet.ensure(region, subnet["network"], subnet["name"], subnet["range"])
              end
            end
          end

          def self.check
            return if Remote.list.empty?
            return if Local.list.empty?
            header :check
            Resources::Validate::Remote.instances(Local.list, Remote.list)
          end

          module Local
            include GClouder::Logging

            def self.section
              ["compute", "networks", "subnets"]
            end

            def self.list
              instances
            end

            def self.validate
              Resources::Validate::Region.instances(
                instances,
                required_keys:  GClouder::Config::Arguments.required(section),
                permitted_keys: GClouder::Config::Arguments.permitted(section)
              )
            end

            def self.instances
              Resources::Region.instances(path: ["subnets"])
            end

            def self.networks
              collection = { "global" => [] }
              list.each { |_region, subnets| subnets.each { |subnet| collection["global"].push({ "name" => subnet["network"] }) } }
              collection.delete_if { |_k, v| v.empty? }
            end
          end

          module Remote
            def self.list
              get_arguments
            end

            def self.get_arguments
              Resources::Remote.instances(
                path:           ["compute", "networks", "subnets"],
                ignore_keys:    ["ip_cidr_range", "region"],
                skip_instances: { "network" => /^default$/ }
              )
            end
          end

          module Subnet
            include GClouder::Resource

            def self.ensure(region, network, subnet, range)
              Resource.ensure :"compute networks subnets", subnet, "--network #{network} --range #{range} --region #{region}"
            end

            def self.purge(region, subnet)
              Resource.purge :"compute networks subnets", subnet, "--region #{region}", indent: 3
            end
          end
        end
      end
    end
  end
end
