#!/usr/bin/env ruby

require "yaml"

module GClouder
  module Config
    module Arguments
      include GClouder::Logging

      def self.arguments
        GClouder::ConfigLoader.load("../../assets/arguments")
      end

      def self.load
        arguments
      end

      def arguments
        Arguments.arguments
      end

      def self.included(klass)
        klass.extend Arguments
      end

      def self.permitted(section)
        GClouder::ConfigSection.find(section, arguments)
      end

      def self.required(section)
        GClouder::ConfigSection.find(section, arguments).delete_if { |key, values| ! values["required"] }
      end
    end
  end
end
