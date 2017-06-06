#!/usr/bin/env ruby

module GClouder
  module Resources
    module Project
      include GClouder::Logging
      include GClouder::Config::Project
      include GClouder::GCloud

      def self.header(stage = :ensure)
        info "[#{stage}] project", title: true
        info
      end

      # unprivileged exists? method for use by non-billing accounts
      def self.exists?
        Resource.resource?("projects", project["project_id"], filter_key: "project_id", silent: true)
      end

      def self.update
        header
        Local.ensure
      end

      module Local
        include GClouder::Config::Project
        include GClouder::Logging
        include GClouder::Shell
        include GClouder::GCloud
        include GClouder::Config::CLIArgs

        def self.ensure
          create_project
          link_project_to_billing_account
        end

        def self.create_project
          if exists?
            good project_id, indent: 2
            return
          end

          # FIXME: wait for project to exist and apis be enabled before continuing..
          # FIXME: enable compute engine api..

          add project_id, indent: 2
          gcloud("alpha projects create #{project_id} --enable-cloud-apis --name=#{project_id}")

          # FIXME: billing account isn't listed until linked..
          #sleep 0.5 until exists? unless cli_args[:dry_run]
        end

        def self.link_project_to_billing_account
          if linked_to_billing_account?
            good "linked to billing account: #{account_id}", indent: 3
            return
          end

          add "link to billing account: #{account_id}", indent: 3
          gcloud("alpha billing accounts projects link #{project_id} --account-id=#{account_id}")
        end

        def self.linked_to_billing_account?
          project_data(project_id)["billingEnabled"]
        end

        def self.exists?
          ! project_data(project_id).empty?
        end

        def self.project_data(project)
          shell("gcloud --format json alpha billing accounts projects list #{account_id} | jq '.[] | select(.projectId == \"#{project}\")'")
        end

        def self.project_id
          project["project_id"]
        end

        def self.account_id
          project["account_id"]
        end
      end
    end
  end
end
