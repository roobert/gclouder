#!/usr/bin/env ruby

module GClouder
  module Resources
    module Compute
      module Networks
        include GClouder::Config::CLIArgs
        include GClouder::Config::Project
        include GClouder::Logging
        include GClouder::Resource::Cleaner

        def self.header(stage = :ensure)
          info "[#{stage}] compute / network", indent: 1, title: true
        end

        def self.ensure
          return if Local.list.empty?
          header

          Local.list.each do |region, networks|
            info region, indent: 2, heading: true
            info
            networks.each do |network|
              Network.ensure(network["name"])
            end
          end
        end

        def self.validate
          return if Local.list.empty?
          header :validate
          Local.validate
        end

        module Local
          include GClouder::Config::CLIArgs
          include GClouder::Config::Project
          include GClouder::Logging

          def self.list
            { "global" => resources }.delete_if { |_k, v| v.empty? }
          end

          def self.resources
            merged = networks.merge(subnet_networks)["global"]
            return [] unless merged
            merged.uniq { |network| network["name"] }
          end

          def self.validate
            return if list.empty?

            failure = false

            list.each do |region, networks|
              info region, indent: 2, heading: true
              networks.each do |network|
                info network["name"], indent: 3, heading: true
                if !network["name"].is_a?(String)
                  bad "#{network['name']} is incorrect type #{network['name'].class}, should be: String", indent: 4
                  failure = true
                end

                if cli_args[:debug] || !cli_args[:output_validation]
                  good "network is a String", indent: 4
                end
              end
            end

            fatal "\nerror: validation failure" if failure
          end

          def self.networks
            GClouder::Resources::Global.instances(path: ["networks"])
          end

          def self.subnet_networks
            GClouder::Resources::Compute::Networks::Subnets::Local.networks
          end
        end

        module Remote
          def self.list
            { "global" => instances.fetch("global", []).map { |network| { "name" => network["name"]  } } }.delete_if { |_k, v| v.empty? }
          end

          def self.instances
            Resources::Remote.instances(
              path:           ["compute", "networks"],
              ignore_keys:    ["auto_create_subnetworks", "subnetworks", "x_gcloud_mode", "range"],
              skip_instances: { "name" => /^default$/ },
            )
          end
        end

        module Network
          include GClouder::GCloud

          def self.ensure(network)
            Resource.ensure :"compute networks", network, "--mode custom"
          end

          def self.purge(network)
            Resource.purge :"compute networks", network
          end
        end
      end
    end
  end
end
