#!/usr/bin/env ruby

require "yaml"

module GClouder
  module Mappings
    module Argument
      include GClouder::Logging

      def self.mappings
        GClouder::ConfigLoader.load("../../assets/mappings/argument")
      end

      def self.load
        mappings
      end

      def mappings
        Argument.mappings
      end

      def self.included(klass)
        klass.extend Argument
      end

      def self.section(section)
        GClouder::ConfigSection.find(section, mappings)
      end
    end
  end
end
