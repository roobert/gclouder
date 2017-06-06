#!/usr/bin/env ruby

module GClouder
  module Resources
    module Validate
      module Remote
        include GClouder::Logging
        include GClouder::Config::Project
        include GClouder::Config::CLIArgs

        def self.instances(local, remote, skip_keys: [])
          remote.each do |region, resources|
            info region, heading: true, indent: 2
            resources.each do |resource|
              #FIXME: This won't work with duplicate names
              local_config = local.fetch(region, []).select {|s| s["name"] == resource["name"] }.first

              failure = false

              next unless local_config

              info resource["name"], indent: 3, heading: true

              local_config.each do |key, value|
                skipped = false
                skip_message = nil

                # FIXME: we should recurse down into the data structure and check the values..
                if value.is_a?(Hash) || value.is_a?(Array)
                  skip_message ||= "(can't validate complex object)"
                  skipped = true
                end

                if skip_keys.include?(key)
                  skip_message ||= "(skip_keys in resource definition)"
                  skipped = true
                else
                  if !resource.key?(key)
                    bad "#{key} (missing key)", indent: 4

                    failure = true
                    next
                  end

                  if value != resource[key]
                    bad "#{key} (\"#{value.to_s.truncate(30)}\" != \"#{resource[key].to_s.truncate(30)}\")", indent: 4

                    failure = true
                    next
                  end
                end

                message = "#{key}" " (#{value.to_s.truncate(60)})"
                message += " [skipped]" if skipped
                message += " #{skip_message}" if skip_message

                good message, indent: 4
              end

              next unless failure

              info
              info "local config:"
              pp local_config.sort.to_h
              info

              info "remote config:"
              pp resource.sort.to_h
              info

              fatal "error: immutable remote resource differs from local definition for resource: #{region}/#{resource["name"]}"
            end
          end
        end
      end
    end
  end
end
