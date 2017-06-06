#!/usr/bin/env ruby

module GClouder
  module Resources
    module Compute
      module Addresses
        include GClouder::GCloud
        include GClouder::Logging
        include GClouder::Resource::Cleaner

        def self.header(stage = :ensure)
          info "[#{stage}] compute / addresses", title: true
        end

        def self.ensure
          return if Local.list.empty?
          header

          if Local.list.key?("global")
            info "global", indent: 2, heading: true
            info
            Local.list["global"].each { |address| Address.ensure(address["name"], "--global") }
          end

          Local.list.each do |region, addresses|
            next if region == "global"
            next unless addresses

            info region, indent: 2, heading: true
            info
            addresses.each do |address|
              Address.ensure(address["name"], "--region #{region}")
            end
          end
        end

        def self.check
          return if Remote.list.empty?
          return if Local.list.empty?
          header :check
          Resources::Validate::Remote.instances(Local.list, Remote.list)
        end

        def self.validate
          return if Local.list.empty?
          header :validate
          Local.validate
        end

        module Local
          include GClouder::Config::Project

          def self.list
            addresses = global.merge regional
            addresses.delete_if { |_k, v| v.empty? }
          end

          def self.global
            Resources::Global.instances(path: ["addresses"])
          end

          def self.section
            %w(compute addresses)
          end

          def self.validate
            Resources::Validate::Region.instances(
              list,
              required_keys:  GClouder::Config::Arguments.required(section),
              permitted_keys: GClouder::Config::Arguments.permitted(section)
            )
          end

          def self.regional
            resources = Resources::Region.instances(path: ["addresses"])

            # get_instances_from_region assumes all keys have configs.. this normalizes
            # the data to match self.global
            resources.each { |k, v| resources[k] = v.to_a.flatten.delete_if(&:nil?) }
          end
        end

        module Remote
          def self.list
            Resources::Remote.instances(
              path: ["compute", "addresses"]
            )
          end
        end

        module Address
          def self.ensure(name, args)
            GClouder::Resource.ensure :"compute addresses", name, args
          end

          def self.purge(namespace, name, args = nil)
          end
        end

        module Resource
          def self.symlink
            Module.const_get "#{self.name.delete(/::Resource$/)}::Address"
          end
        end
      end
    end
  end
end
