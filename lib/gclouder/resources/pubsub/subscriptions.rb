#!/usr/bin/env ruby

module GClouder
  module Resources
    module PubSub
      module Subscriptions
        include GClouder::Config::CLIArgs
        include GClouder::Config::Project
        include GClouder::Logging
        include GClouder::Resource::Cleaner

        def self.header(stage = :ensure)
          info "[#{stage}] pub/sub / subscriptions", indent: 1, title: true
        end

        def self.ensure
          return if Local.list.empty?
          header

          Local.list.each do |region, subscriptions|
            info region, indent: 2, heading: true
            info
            subscriptions.each do |subscription|
              Subscription.ensure(subscription)
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

            list.each do |region, subscriptions|
              info region, indent: 2, heading: true
              subscriptions.each do |subscription|
                info subscription["name"], indent: 3, heading: true
                if !subscription["name"].is_a?(String)
                  bad "#{subscription['name']} is incorrect type #{subscription['name'].class}, should be: String", indent: 4
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
            GClouder::Resources::Global.instances(path: %w(pubsub subscriptions))
          end
        end

        module Remote
          def self.list
            { "global" => instances.fetch("global", []).map { |subscription| { "name" => subscription["subscription_id"] } } }.delete_if { |_k, v| v.empty? }
          end

          def self.instances
            Resources::Remote.instances(
              path: %w(beta pubsub subscriptions)
            )
          end
        end

        module Subscription
          include GClouder::GCloud
          include GClouder::Helpers

          def self.args(subscription)
            hash_to_args(subscription)
          end

          def self.ensure(subscription)
            Resource.ensure :"beta pubsub subscriptions", subscription["name"], args(subscription), filter_key: "subscriptionId", indent: 3
          end

          def self.purge(subscription)
            Resource.purge :"beta pubsub subscriptions", subscription["name"]
          end
        end
      end
    end
  end
end
