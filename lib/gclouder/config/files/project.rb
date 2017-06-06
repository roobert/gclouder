#!/usr/bin/env ruby

module GClouder
  module Config
    module Files
      module Project
        include GClouder::Config::CLIArgs
        include GClouder::Helpers

        def self.included(klass)
          klass.extend project
        end

        def project
          Project.project
        end

        def self.project
          to_deep_merge_hash(YAML.load_file(cli_args[:config]))
        end
      end
    end
  end
end
