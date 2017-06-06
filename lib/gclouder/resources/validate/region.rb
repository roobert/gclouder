#!/usr/bin/env ruby

module GClouder
  module Resources
    module Validate
      module Region
        include GClouder::Logging
        include GClouder::Config::Project
        include GClouder::Config::CLIArgs
        extend Local

        def self.instances(data, required_keys: {}, permitted_keys: {}, ignore_keys: [], skip_region: false, indent: 0)
          data.each do |region, instances|
            info region, indent: 2 + indent, heading: true unless skip_region
            instances.each do |instance|
              info instance["name"], indent: 3 + indent, heading: true

              next if !has_unknown_keys?(instance, permitted_keys, ignore_keys, indent: indent) &&
                has_required_keys?(instance, required_keys, ignore_keys, indent: 4 + indent)

              fatal "\nerror: validation failure"
            end
          end
        end
      end
    end
  end
end
