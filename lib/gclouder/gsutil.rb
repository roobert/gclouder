#!/usr/bin/env ruby

module GClouder
  module GSUtil
    include GClouder::Shell
    include GClouder::Config::CLIArgs
    include GClouder::Config::Project

    def self.included(klass)
      klass.extend GSUtil
    end

    def gsutil(command, args, force: false)
      info "# gsutil #{command} -p #{project['project_id']} #{args}" if cli_args[:debug]

      return if cli_args[:dry_run] && !force

      gsutil_exec(command, args)
    end

    def gsutil_exec(command, args)
      shell("gsutil #{command} -p #{project['project_id']} #{args}")
    end
  end
end
