#!/usr/bin/env ruby

require "yaml"

module GClouder
  module Config
    module Defaults
      include GClouder::Logging

      def self.defaults
        GClouder::ConfigLoader.load("../../assets/defaults")
      end

      def self.load
        defaults
      end

      def defaults
        Defaults.defaults
      end

      def self.included(klass)
        klass.extend Defaults
      end

      def self.section(section)
        GClouder::ConfigSection.find(section, defaults)
      end

      def self.section?(section)
        GClouder::ConfigSection.find(section, defaults, silent: true)
      end
    end
  end
end
