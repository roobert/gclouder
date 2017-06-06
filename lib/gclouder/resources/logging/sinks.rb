#!/usr/bin/env ruby

module GClouder
  module Resources
    module Logging
      module Sinks
        include GClouder::Config::CLIArgs
        include GClouder::Config::Project
        include GClouder::Logging
        include GClouder::Resource::Cleaner

        def self.header(stage = :ensure)
          info "[#{stage}] logging / sinks", indent: 1, title: true
        end

        def self.ensure
          return if Local.list.empty?
          header

          Local.list.each do |region, sinks|
            info region, indent: 2, heading: true
            info
            sinks.each do |sink|
              Sink.ensure(sink)
            end
          end
        end

        def self.validate
          return if Local.list.empty?
          header :validate
          Local.validate
        end

        module Local
          include GClouder::Config::CLIArgs
          include GClouder::Config::Project
          include GClouder::Logging

          def self.validate
            return if list.empty?

            failure = false

            list.each do |region, sinks|
              info region, indent: 2, heading: true
              sinks.each do |sink|
                info sink["name"], indent: 3, heading: true
                if !sink["name"].is_a?(String)
                  bad "#{sink['name']} is incorrect type #{sink['name'].class}, should be: String", indent: 4
                  failure = true
                end

                if cli_args[:debug] || !cli_args[:output_validation]
                  good "name is a String", indent: 4
                end
              end
            end

            fatal "\nerror: validation failure" if failure
          end

          def self.list
            GClouder::Resources::Global.instances(path: %w(logging sinks))
          end
        end

        module Remote
          def self.list
            { "global" => instances.fetch("global", []).map { |sink| { "name" => sink["sink_id"] } } }.delete_if { |_k, v| v.empty? }
          end

          def self.instances
            Resources::Remote.instances(
              path: %w(beta logging sinks)
            )
          end
        end

        module Sink
          include GClouder::GCloud

          def self.args(sink)
            "#{sink['destination']} " + hash_to_args(sink.delete_if { |k| k == "destination" })
          end

          def self.ensure(sink)
            Resource.ensure :"beta logging sinks", sink["name"], args(sink)
          end

          def self.purge(sink)
            Resource.purge :"beta logging sinks", sink["name"]
          end
        end
      end
    end
  end
end
