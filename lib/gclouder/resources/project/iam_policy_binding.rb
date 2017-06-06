#!/usr/bin/env ruby

module GClouder
  module Resources
    module Project
      module IAMPolicyBinding
        include GClouder::Config::Project
        include GClouder::Logging
        include GClouder::GCloud
        include GClouder::Config::CLIArgs

        def self.header(stage = :ensure)
          info "[#{stage}] project / iam-policy-binding", indent: 1, title: true
        end

        def self.clean
          return if undefined.empty?

          header :clean

          undefined.each do |region, roles|
            info region, indent: 2, heading: true
            roles.each do |role|
              info role["name"], indent: 3, heading: true
              role["members"].each do |member|
                message = member
                message += " (not defined locally)"
                warning message, indent: 4
              end
            end
          end
        end

        def self.unmanaged_service_account?(member)
          is_service_account?(member) && !member.include?(project["project_id"])
        end

        def self.is_service_account?(member)
          member.include? "gserviceaccount.com"
        end

        def self.undefined
          # each remote role
          Remote.list.each_with_object({}) do |(region, remote_roles), collection|
            # each role, {owner, ...}
            remote_roles.each do |remote_role|
              role_found = false

              next unless remote_role.key?("members")

              # for each remote member
              remote_role["members"].each do |remote_member|

                next unless Local.list.key?("global")

                # see if the members role exists locally
                Local.list["global"].each do |e|
                  next unless e["name"] == remote_role["name"]

                  role_found = true

                  # if it does then check if member is in member list for role

                  # member is defined, so skip it
                  next if e["members"].include?(remote_member)

                  # member is one we don't want to manage, so skip it
                  next if unmanaged_service_account?(remote_member)

                  # member is undefined so add it to collection

                  collection["global"] ||= []

                  # add role if it doesn't exist in collection
                  if !resource?(collection["global"], remote_role["name"])
                    collection["global"] <<  { "name" => remote_role["name"], "members" => [] }
                  end

                  # add memeber to role
                  resource_array_append(collection["global"], remote_role["name"], "members", remote_member)
                end
              end

              # if entire role is missing from local..
              next if role_found
              collection["global"] ||= []
              collection["global"] << remote_role
            end
          end
        end

        def self.resource?(resources, resource)
          !resources.fetch_with_default("name", resource, {}).empty?
        end

        def self.resource_array_append(resources, resource_name, resource_key, obj)
          resource = resources.fetch_with_default("name", resource_name, {})
          resource[resource_key] ||= []
          resource[resource_key] << obj
        end

        def self.validate
          return if Local.list.empty?
          header :validate

          failure = false

          Local.list.each do |region, roles|
            info region, indent: 2, heading: true

            next if roles.empty?

            roles.each do |role|
              if !role.is_a?(Hash)
                bad "role type is not a Hash: #{role}"
                failure = true
                next
              end

              if !role.key?("name")
                bad "missing key: name"
                failure = true
                next
              end

              if !role.key?("members")
                bad "missing key: members"
                failure = true
                next
              end

              info role["name"], indent: 3, heading: true

              unless role["members"].is_a?(Array)
                bad "value not an array for key: #{role}", indent: 4
                fatal "failure due to invalid config"
              end

              next unless role.key?("members")

              role["members"].each do |member|

                if !member.is_a?(String)
                  bad "member isn't a String: #{member}", indent: 3
                  failure = true
                  next
                end

                info member, indent: 4, heading: true

                good "member is a String", indent: 5

                case member
                when /^user:/
                  good "member is a 'user'", indent: 5
                when /^group:/
                  good "member is a 'group'", indent: 5
                when /^serviceAccount:/
                  good "member is a 'serviceAccount'", indent: 5
                when /^sink:/
                  good "member is a 'sink'", indent: 5
                else
                  bad "member is an unknown type", indent: 5
                  failure = true
                end
              end
            end
          end

          fatal "config validation failure" if failure
        end

        def self.sink(member)
          gcloud("beta logging sinks describe #{member.gsub('sink:', '')} | jq -r .writer_identity", force: true).chomp
        rescue
          fatal "failed to lookup writer identity for sink: #{member}"
        end

        def self.ensure
          return if Local.list.empty?
          header

          Local.list.each do |region, roles|
            info region, indent: 2, heading: true

            roles.each do |role|
              info role["name"], indent: 3, heading: true

              role["members"].each do |member|
                if member.start_with?("sink:")
                  sink_name = member
                  member = sink(member)

                  if member.empty? && cli_args[:dry_run]
                    add "unknown - serviceAccount does not exist [#{sink_name}]", indent: 4
                    next
                  elsif member.empty?
                    fatal "unable to find sink serviceAccount (writer identity) - does sink exist for name: #{sink_name}"
                  end
                end

                if policy_member?(project_id, role["name"], member)
                  good member, indent: 4
                  next
                end

                if project_owner?
                  add member, indent: 4
                  Binding.ensure(project_id, member, role["name"])
                  next
                end

                add "#{member} [skipping] (insufficient permissions to create user)", indent: 4
              end
            end
          end
        end

        def self.policy_member?(project, role, member)
          bindings = gcloud("--format json projects get-iam-policy #{project} | jq '.bindings[] | select(.role == \"roles/#{role}\")'", force: true)
          return false if bindings.empty?
          fatal "could not get policy bindings for project: #{project}" unless bindings.key?("members")
          bindings["members"].include?(member)
        end

        def self.project_id
          project["project_id"]
        end

        def self.executioner
          GClouder::Project::ID.id
        end

        def self.executioner_formatted
          "user:#{executioner.strip}"
        end

        def self.project_owner?
          return false unless executioner
          policy_member?(project_id, "owner", executioner_formatted)
        end

        module Local
          include GClouder::GCloud
          include GClouder::Config::Project
          include GClouder::Logging

          def self.list
            return {} unless project.key?("iam")
            { "global" => project["iam"] }
          end
        end

        module Remote
          include GClouder::GCloud
          include GClouder::Config::Project
          include GClouder::Logging

          def self.list
            resources.each_with_object({ "global" => [] }) do |data, collection|
              data["name"] = data["role"].gsub("roles/", "")
              data.delete("role")
              collection["global"] << data
            end
          end

          def self.resources
            gcloud("--format json projects get-iam-policy #{project_id} | jq .bindings", force: true)
          end

          def self.policy_member?(project, role, member)
            bindings = gcloud("--format json projects get-iam-policy #{project} | jq '.bindings[] | select(.role == \"roles/#{role}\")'", force: true)
            return false if bindings.empty?
            fatal "could not get policy bindings for project: #{project}" unless bindings.key?("members")
            bindings["members"].include?(member["name"])
          end

          def self.project_id
            project["project_id"]
          end
        end

        module Binding
          include GClouder::GCloud

          def self.ensure(project_id, name, role)
            gcloud("projects add-iam-policy-binding #{project_id} --member='#{name}' --role='roles/#{role}'")
          end
        end
      end
    end
  end
end
