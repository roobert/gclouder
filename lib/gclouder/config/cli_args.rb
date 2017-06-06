#!/usr/bin/env ruby

module GClouder
  module Config
    module CLIArgs
      def self.cli_args
        @cli_args ||= { debug: false }
      end

      def cli_args
        CLIArgs.cli_args
      end

      def self.included(klass)
        klass.extend CLIArgs
      end

      def self.valid_resources
        GClouder.resources.map { |resource| resource[:name] }
      end

      def self.load
        option_parser = Trollop::Parser.new do
          banner GClouder::Header.display + "\n \n "

          # required
          opt :config,                       "path to config file\n ", type: :string, required: true

          # level of operation
          opt :dry_run,                      "passive mode"
          opt :purge,                        "remove unmanaged resources (destructive!)\n "

          # authentication / for automation
          opt :activate_service_accounts,    "activate service account(s) (for use when running using service accounts, i.e: with CI)"
          opt :keys_dir,                     "path to directory with service account key files (for use with --activate-service-accounts)\n ", type: :string

          # which resources / actions
          # FIXME: integrate checks for required permissions into Project module
          opt :bootstrap,                    "create project (requires being run as non-service account)"
          # this should be type: proc and validate that the params match one of: validate, ensure, clean
          opt :stages,                       "which stages to run (validate,ensure,clean) [csv]", type: :string
          opt :resources,                    "which resources to update [csv]", type: :string
          opt :skip_cross_project_resources, "skip resources which don't reside in main project\n "

          # output
          opt :debug,                        "print commands to be executed, and stack traces"
          opt :trace,                        "print stack traces"
          opt :no_color,                     "disable color\n \n "
        end

        @cli_args = Trollop.with_standard_exception_handling(option_parser) do
          raise Trollop::HelpNeeded if ARGV.empty?
          option_parser.parse ARGV
        end

        String.disable_colorization = @cli_args[:no_color]

        if @cli_args[:resources]
          @cli_args[:resources].split(',').each do |resource|
            unless valid_resources.include?(resource)
              puts "valid resources: #{valid_resources.join(', ')}"
              puts "invalid resource for --resources flag: #{resource}"
              exit 1
            end
          end
        end

        check
      end

      def self.check
        raise ArgumentError, "config file not specified" unless cli_args[:config_given]
        raise ArgumentError, "config file not readable: #{cli_args[:config]}" unless File.readable?(cli_args[:config])
      end
    end
  end
end
