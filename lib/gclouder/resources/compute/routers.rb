#!/usr/bin/env ruby

module GClouder
  module Resources
    module Compute
      module Routers
        include GClouder::Config::CLIArgs
        include GClouder::Config::Project
        include GClouder::Logging
        include GClouder::Helpers
        include GClouder::Config::Arguments
        include GClouder::Resource::Cleaner

        def self.header(stage = :ensure)
          info "[#{stage}] compute / router", title: true
        end

        def self.validate
          return if Local.list.empty?
          header :validate
          Local.validate
        end

        def self.ensure
          return if Local.list.empty?
          header

          Local.list.each do |region, routers|
            next if routers.empty?
            info region, heading: true, indent: 2

            routers.each do |router|
              info
              Router.ensure(region, router["name"], hash_to_args(router))
            end
          end
        end

        module Local
          include GClouder::Logging

          def self.section
            ["compute", "routers"]
          end

          def self.list
            Resources::Region.instances(path: ["routers"])
          end

          def self.validate
            Resources::Validate::Region.instances(
              list,
              required_keys:  GClouder::Config::Arguments.required(section),
              permitted_keys: GClouder::Config::Arguments.permitted(section),
              # ignore ASN until Fixnums are supported
              ignore_keys: [ "asn" ],
            )
          end
        end

        module Remote
          def self.list
            Resources::Remote.instances(
              path: ["compute", "routers"],
            )
          end
        end

        module Router
          include GClouder::Resource

          def self.ensure(region, router, args)
            Resource.ensure :"compute routers", router, "--region #{region} #{args}"
          end

          def self.purge(region, router)
            Resource.purge :"compute routers", router, "--region #{region}"
          end
        end
      end
    end
  end
end
