#!/usr/bin/env ruby

module GClouder
  module Resources
    module Validate
      module Global
        include GClouder::Logging
        include GClouder::Config::Project
        include GClouder::Config::CLIArgs
        include Local

        def self.instances(data, required_keys: {}, permitted_keys: {}, ignore_keys: [])
          return unless data.key?("global")

          data["global"].each do |instance|
            info instance["name"], heading: true, indent: 3

            next if !has_unknown_keys?(instance, permitted_keys, ignore_keys) &&
              has_required_keys?(instance, required_keys, ignore_keys, indent: 3)

            fatal "\nerror: validation failure"
          end
        end
      end
    end
  end
end
