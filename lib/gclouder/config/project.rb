#!/usr/bin/env ruby

module GClouder
  module Config
    module Project
      include GClouder::Logging
      include GClouder::Helpers

      def self.project
        @project
      end

      def project
        Project.project
      end

      def self.load
        @project = GClouder.resources.each_with_object(GClouder::Config::Files::Project.project) do |resource, config|
          next unless module_exists? "#{resource[:module]}::Config"

          config = resource[:module]::Config.merged(config)
        end

        fatal "no project_id found in config" unless project.key?("project_id")
      end

      private

      def self.included(klass)
        klass.extend Project
      end
    end
  end
end
