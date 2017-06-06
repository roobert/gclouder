#!/usr/bin/env ruby

module GClouder
  module GCloud
    include GClouder::Logging
    include GClouder::Shell
    include GClouder::Helpers
    include GClouder::Config::Project
    include GClouder::Config::CLIArgs

    def self.included(klass)
      klass.extend GCloud
    end

    def gcloud(command, force: false, failure: true, silent: false, project_id: nil)
      project_id = verify(project_id)

      GClouder::Project::ID.switch(project_id)

      if cli_args[:dry_run] && !force
        debug "# gcloud --quiet --format json --project=#{project_id} #{command}" if cli_args[:debug]
        GClouder::Project::ID.reset
        return
      end

      result = shell("gcloud --quiet --format json --project=#{project_id} #{command}", failure: failure, silent: silent)

      GClouder::Project::ID.reset

      valid_json?(result) ? JSON.parse(result.to_s) : result
    end

    def verify(project_id)
      project_id ||= project["project_id"]
      return project_id if project_id
      raise StandardError, "project_id not detected"
    end
  end
end
