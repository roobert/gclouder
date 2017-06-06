#!/usr/bin/env ruby

module GClouder
  module Resources
    module Compute
      module ProjectInfo
        module SSHKeys
          include GClouder::Logging
          include GClouder::Config::Project
          include GClouder::Config::CLIArgs

          def self.header(stage = :ensure)
            info "[#{stage}] compute / metadata / ssh_keys", title: true
          end

          def self.clean
            return unless project.key?("users")
            header :clean
          end

          def self.check
          end

          def self.validate
            return if Local.data.empty?
            header :validate
            Local.validate
          end

          def self.ensure
            return unless project.key?("users")
            header :ensure

            info "global", heading: true, indent: 2
            info

            Local.data.each do |user_data|
              description = user_data[:description]

              user = Remote.data.find { |entry| entry[:description] == description }

              # user doesn't exist, add it..
              if user.nil?
                add description
                next
              end

              # user exists but has been modified
              if user_data[:key] != user[:key]
                change description
                next
              end

              # user exists and is the same
              good description
            end

            Remote.data.each do |user_data|
              description = user_data[:description]

              next if Local.data.find { |entry| entry[:description] == description }

              # user isn't defined locally, remove it
              remove description, indent: 3
            end

            return if Local.list == Remote.list
            return if cli_args[:dry_run]

            Key.ensure(Local.list)
          end

          module Local
            include GClouder::Config::Project
            include GClouder::Logging

            def self.list
              return [] unless project.key?("users")

              project["users"].sort
            end

            def self.data
              list.map do |line|
                components = line.split
                user, type = components[0].split(":")
                key = components[1]
                description = components.length >= 2 ? components[2] : components[0]

                { key: key, type: type, user: user, description: description }
              end
            end

            def self.validate
              return if data.empty?

              info "global", heading: true, indent: 2

              data.each do |entry|
                info
                info entry[:description], indent: 3

                if entry[:user].is_a?(String)
                  good "user is a String (#{entry[:user]})", indent: 4
                else
                  bad "user is a String (#{entry[:user]})", indent: 4
                end

                if entry[:key].is_a?(String)
                  good "key is a String (#{entry[:key].reverse.truncate(20).reverse})", indent: 4
                else
                  bad "key isn't a String (#{entry[:key]})", indent: 4
                end

                if entry[:type].is_a?(String)
                  good "type is a String (#{entry[:type]})", indent: 4
                else
                  bad "type isn't a String (#{entry[:type]})", indent: 4
                end

                # check if description exists for key
                # output useruser
                # output key.truncate
                # output description
              end
            end
          end

          module Remote
            include GClouder::GCloud

            def self.list
              keys = metadata.dig("items")

              return [] unless keys
              return [] if keys.empty?

              keys.delete_if { |h| h["key"] != "sshKeys" }
              keys[0]["value"].split("\n").delete_if { |key| key =~ /^gke-/ }.sort
            end

            def self.data
              list.map do |line|
                components = line.split
                user, type = components[0].split(":")
                key = components[1]
                description = components.length >= 2 ? components[2] : components[0]

                { key: key, type: type, user: user, description: description }
              end
            end

            def self.metadata
              gcloud("compute project-info describe | jq -r '.commonInstanceMetadata'", force: true)
            end
          end
        end

        module Key
          include GClouder::Config::Project
          include GClouder::GCloud

          def self.ensure(list)
            list = list.join("\n") if list.is_a?(Array)
            gcloud("compute project-info add-metadata --metadata sshKeys=\"#{list}\"")
          end
        end
      end
    end
  end
end
