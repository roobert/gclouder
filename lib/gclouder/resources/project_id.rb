#!/usr/bin/env ruby

module GClouder
  module Project
    module ID
      include GClouder::Config::Project
      include GClouder::Config::CLIArgs
      include GClouder::Shell

      def self.id
        @id
      end

      def self.load
        @id ||= current
        switch(project["project_id"]) if @id.nil?
      end

      def self.current
        id = shell("gcloud auth list --format json | jq -r '.[] | select(.status == \"ACTIVE\") | .account'")
        return id if !id.empty?
        return if cli_args[:activate_service_accounts]
        bail
      end

      def self.bail
        puts "not authenticated against API and --activate-service-accounts option not passed"
        puts ""
        puts "please either:"
        puts ""
        puts "  run: gcloud auth login && gcloud auth application-default login"
        puts ""
        puts "  or: specify --activate-service-accounts flag and make sure the relevant keys exist in the keys dir"
        puts ""
        exit 1
      end

      def self.switch(project_id)
        return unless project_id
        if cli_args[:activate_service_accounts]
          shell("gcloud --quiet auth activate-service-account --key-file #{key_file(project_id)}")
        end
      end

      def self.rescue
        if @id.nil?
          shell("gcloud config unset account")
          return
        end

        switch(@id)
      end

      def self.reset
        switch(project["project_id"])
      end

      def self.default
        shell("gcloud config set account #{project['project_id']}")
      end

      def self.dir
        cli_args[:keys_dir] || File.join(ENV["HOME"], "keys")
      end

      def self.key_file(project_id)
        File.join(dir, "gcloud-service-key-#{project_id}.json")
      end
    end
  end
end
