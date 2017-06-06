#!/usr/bin/env ruby

module GClouder
  module ConfigSection
    include GClouder::Logging

    def self.included(klass)
      klass.extend ConfigSection
    end

    def self.find(path, data, silent: false)
      raise StandardError, "find: path argument must be an array: #{path.inspect}" unless path.is_a?(Array)
      raise StandardError, "find: data argument must be an hash: #{path.inspect}" unless data.is_a?(Hash)

      section = data.dig(*path)

      if section
        return silent ? true : section
      end

      return false if silent

      fatal "can't find key in data: #{path}"
    end
  end
end
