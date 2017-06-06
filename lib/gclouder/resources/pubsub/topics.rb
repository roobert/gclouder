#!/usr/bin/env ruby

module GClouder
  module Resources
    module PubSub
      module Topics
        include GClouder::Config::CLIArgs
        include GClouder::Config::Project
        include GClouder::Logging
        include GClouder::Resource::Cleaner

        def self.header(stage = :ensure)
          info "[#{stage}] pub/sub / topics", indent: 1, title: true
        end

        def self.ensure
          return if Local.list.empty?
          header

          Local.list.each do |region, topics|
            info region, indent: 2, heading: true
            info
            topics.each do |topic|
              Topic.ensure(topic["name"])
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

          # FIXME: improve validation
          def self.validate
            return if list.empty?

            failure = false

            list.each do |region, topics|
              info region, indent: 2, heading: true
              topics.each do |topic|
                info topic["name"], indent: 3, heading: true
                if !topic["name"].is_a?(String)
                  bad "#{topic['name']} is incorrect type #{topic['name'].class}, should be: String", indent: 4
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
            GClouder::Resources::Global.instances(path: %w(pubsub topics))
          end
        end

        module Remote
          def self.list
            { "global" => instances.fetch("global", []).map { |topic| { "name" => topic["topic_id"] } } }.delete_if { |_k, v| v.empty? }
          end

          def self.instances
            Resources::Remote.instances(
              path: %w(beta pubsub topics)
            )
          end
        end

        module Topic
          include GClouder::GCloud

          def self.ensure(topic)
            Resource.ensure :"beta pubsub topics", topic, filter_key: "topicId"
          end

          def self.purge(topic)
            Resource.purge :"beta pubsub topics", topic
          end
        end
      end
    end
  end
end
