#!/usr/bin/env ruby

require "yaml"

module GClouder
  module Mappings
    module File
      include GClouder::Logging

      def self.mappings
        GClouder::ConfigLoader.load("../../assets/mappings/file")
      end

      def self.load
        mappings
      end

      def file
        File.mappings
      end

      def self.included(klass)
        klass.extend File
      end

      def self.section(section)
        GClouder::ConfigSection.find(section, mappings)
      end
    end
  end
end
