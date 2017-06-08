#!/usr/bin/env ruby

module GClouder
  module Resource
    include GClouder::GCloud
    include GClouder::Config::CLIArgs
    include GClouder::Logging

    def self.feedback(action, resource, name, extra_info: nil, indent: 3, silent: false)
      return if silent
      send action, "#{name} #{extra_info}", indent: indent
    end

    def self.resource?(resource, name, args = nil, filter_key: "name", filter: "#{filter_key} ~ ^#{name}$", project_id: nil, silent: false, extra_info: nil, indent: 3)
      exists = \
        gcloud("#{resource} list --filter '#{filter}' #{args} | jq '. | length'", force: true, silent: silent, project_id: project_id)

      # if silent is specified then shell call returns truthy, otherwise integer
      exists = exists > 0 ? true : false if !silent

      if exists
        feedback("good", resource, name, extra_info: extra_info, indent: indent, silent: silent)
        return true
      end

      false
    end

    def self.describe(resource, name, args = nil, force: true, failure: true, silent: false, project_id: nil)
      return if resource?(resource, name, silent: silent, project_id: project_id)
      gcloud "#{resource} describe #{name} #{args}", force: force, failure: failure, silent: silent, project_id: project_id
    end

    def self.ensure(resource, name, args = nil, project_id: nil, extra_info: nil, silent: false, indent: 3, filter_key: "name")
      return if resource?(resource, name, project_id: project_id, extra_info: extra_info, silent: silent, indent: indent, filter_key: filter_key)
      feedback("add", resource, name, extra_info: extra_info, indent: indent, silent: silent)
      gcloud "#{resource} create #{name} #{args}", project_id: project_id, silent: silent
    end

    def self.purge(resource, name, args = nil, project_id: nil, silent: false, indent: 3)
      return unless resource?(resource, name, project_id: project_id, silent: true, indent: indent)
      extra_info = "[skipped] (--purge not specified)" unless cli_args[:purge]
      feedback("remove", resource, name, extra_info: extra_info, indent: indent, silent: silent)
      gcloud "#{resource} delete #{name} #{args}", project_id: project_id if cli_args[:purge]
    end

    def self.list(resource, args = nil, snake_case: false, project_id: nil)
      list = gcloud "#{resource} list #{args}", force: true, project_id: project_id
      snake_case ? list.to_snake_keys : list
    end

    module Find
      include GClouder::GCloud

      def self.zone(resource, name, region, project_id: nil)
        zones = %w(b c d).map { |zone| region + "-" + zone }

        zones.each do |zone|
          return zone if gcloud "#{resource} describe #{name} --zone=#{zone}", force: true, failure: false, silent: true, project_id: project_id
        end

        false
      end
    end
  end
end
