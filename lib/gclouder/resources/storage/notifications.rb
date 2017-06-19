#!/usr/bin/env ruby

module GClouder
  module Resources
    module Storage
      module Notifications
        include GClouder::Logging
        include GClouder::Shell

        def self.header(stage = :ensure)
          info "[#{stage}] storage / notifications", title: true, indent: 1
        end

        def self.validate
          return if Local.list.empty?
          header :validate
          Local.validate
        end

        def self.ensure
          return if Local.list.empty?
          header

          Local.list.each do |region, region_config|
            info region, heading: true, indent: 2
            region_config.each do |notification|
              info
              Notification.ensure(notification)
            end
          end
        end

        module Local
          def self.list
            instances
          end

          def self.validate
            # Validation knowledge included here because we don't have arguments parser for gsutil.
            # We also don't support every key that gsutil does. See Notification.ensure() below.
            permitted_and_required_keys = {
              "bucket"=>{"type"=>"String", "required"=>true},
              "topic"=>{"type"=>"String", "required"=>true},
              "events"=>{"type"=>"Array", "required"=>false},
              "prefix"=>{"type"=>"String", "required"=>false}
            }

            Resources::Validate::Region.instances(
              instances,
              permitted_keys: permitted_and_required_keys
            )
          end

          def self.instances
            Resources::Region.instances(path: ["storage", "notifications"])
          end
        end

        module Notification
          include GClouder::GSUtil
          include GClouder::Config::CLIArgs

          def self.notification_exists?(notification)
            notifications_exist = gsutil_exec("notification list", " gs://#{notification["bucket"]} > /dev/null 2>&1 && echo 0 || echo 1").to_i == 0
            if not notifications_exist
              return false
            end

            return gsutil("notification list", "gs://#{notification["bucket"]}", force: true)
              .include?("projects/#{project["project_id"]}/topics/#{notification["topic"]}")

          end

          def self.ensure(notification)
            if notification_exists?(notification)
              good "notification topic: #{notification["name"]}; bucket: #{notification["bucket"]}", indent: 4
              return
            end

            event_type_args = ""
            if notification.has_key?("events")
              event_type_args = "-e #{notification["events"].join(",")}"
            end
            prefix_arg = ""
            if notification.has_key?("prefix")
              prefix_arg = "-p #{notification["prefix"]}"
            end

            args = "-t #{notification["name"]} #{prefix_arg} #{event_type_args} -f json gs://#{notification["bucket"]}"

            add "notification topic: #{notification["name"]}; bucket: #{notification["bucket"]}", indent: 4
            gsutil "notification create", args
          end
        end
      end
    end
  end
end
