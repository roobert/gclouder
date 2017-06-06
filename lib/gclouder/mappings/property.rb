#!/usr/bin/env ruby

require "yaml"

module GClouder
  module Mappings
    module Property
      include GClouder::Logging

      def self.mappings
        YAML.load_file(::File.join(::File.dirname(__FILE__), "../../../assets/mappings/property.yml"))
      end

      def self.load
        mappings
      end

      def mappings
        Property.mappings
      end

      def self.included(klass)
        klass.extend Property
      end

      def self.section(section)
        GClouder::ConfigSection.find(section, mappings)
      end
    end
  end
end
