#!/usr/bin/env ruby

module GClouder
  module Resources
    module Validate
      module Local
        include GClouder::Logging

        def self.included(klass)
          klass.extend Local
        end

        # FIXME: this should probably recurse
        def has_required_keys?(instance, required_keys, ignore_keys, indent: 3)
          success = true

          required_keys["name"] = {
            "type" => "String",
            "required" => true
          }

          required_keys.each do |key, data|
            next if ignore_keys.include?(key)

            if !instance.key?(key)
              bad "#{key} is missing", indent: indent
              success = false
            end
          end

          success
        end

        def has_unknown_keys?(instance, permitted_keys, ignore_keys, indent: 0)
          success = false

          # a name is required for every resources
          permitted_keys["name"] = {
            "type" => "String",
            "required" => true
          }

          instance.each do |key, value|
            next if ignore_keys.include?(key)

            if !permitted_keys.key?(key)
              bad "#{key} is an invalid key", indent: 4 + indent
              success = true
              next
            end

            required_type = Object.const_get(permitted_keys[key]["type"])

            if !value.is_a?(required_type)
              bad "#{key} invalid type: #{value.class} (should be: #{required_type})", indent: 4 + indent
              success = true
              next
            end

            good "#{key} is a #{required_type} (#{value})", indent: 4 + indent
          end

          success
        end
      end
    end
  end
end
