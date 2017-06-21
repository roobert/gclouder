#!/usr/bin/env ruby

module GClouder
  module Resources
    module Functions
      module Function
        include GClouder::Config::CLIArgs
        include GClouder::Logging
        include GClouder::Resource::Cleaner
        include GClouder::Config::Project

        def self.header(stage = :ensure)
          info "[#{stage}] functions / function", indent: 1, title: true
        end

        def self.ensure
          return if Local.list.empty?
          header

          Local.list.each do |region, functions|
            info region, indent: 2, heading: true
            info
            functions.each do |function|
              Function.ensure(region, function)
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

          def self.validate
            Resources::Validate::Region.instances(
              list,
              required_keys:  GClouder::Config::Arguments.required(%w(functions)),
              permitted_keys: GClouder::Config::Arguments.permitted(%w(functions))
            )
          end

          def self.list
            Resources::Region.instances(path: %w(functions))
          end
        end

        module Remote
          def self.list
            Resources::Remote.instances(
              path: %w(beta functions)
            )
          end
        end

        module Function
          include GClouder::GCloud

          def self.ensure(region, function)
            filter_value = "projects/#{project['project_id']}/locations/#{region}/functions/#{function["name"]}"
            type = Resource::resource?("beta functions", function["name"], filter_value: filter_value) ? "change" : "add"

            Resource::feedback(type, "beta functions", function["name"])
            gcloud "beta functions deploy #{function["name"]} #{hash_to_args(function)} --region=#{region}"
          end

          def self.purge(region, function)
            Resource.purge :"beta functions", function["name"], "--region=#{region}"
          end
        end
      end
    end
  end
end
