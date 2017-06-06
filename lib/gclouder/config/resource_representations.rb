#!/usr/bin/env ruby

require "yaml"

module GClouder
  module Config
    module ResourceRepresentations
      include GClouder::Logging

      def self.properties
        @properties ||= GClouder::ConfigLoader.load("../../assets/resource_representations")
      end

      def self.load
        properties
      end

      def properties
        ResourceRepresentations.properties
      end

      def self.included(klass)
        klass.extend ResourceRepresentations
      end

      def self.section(section)
        GClouder::ConfigSection.find(section, properties)
      end
    end
  end
end
