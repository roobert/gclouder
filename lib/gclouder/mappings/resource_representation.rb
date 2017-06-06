#!/usr/bin/env ruby

require "yaml"

module GClouder
  module Mappings
    module ResourceRepresentation
      include GClouder::Logging

      def self.mappings
        GClouder::ConfigLoader.load("../../assets/resource_representations")
      end

      def self.load
        mappings
      end

      def resource_representation
        ResourceRepresentation.mappings
      end

      def self.included(klass)
        klass.extend ResourceRepresentation
      end

      def self.section(section)
        GClouder::ConfigSection.find(section, mappings)
      end
    end
  end
end
