#!/usr/bin/env ruby

module GClouder
  module Resources
    module Storage
      module Buckets
        include GClouder::Logging
        include GClouder::Shell
        include GClouder::Resource::Cleaner

        def self.header(stage = :ensure)
          info "[#{stage}] storage / buckets", title: true, indent: 1
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
            region_config.each do |bucket|
              info
              Bucket.ensure(region, bucket)
            end
          end
        end

        module Local
          def self.list
            instances
          end

          def self.validate
            # Validation knowledge included here because we don't have arguments parser for gsutil.
            # We also don't support every key that gsutil does. See Bucket.ensure() below.
            permitted_and_required_keys = {
              "default_access"=>{"type"=>"String", "required"=>true}
            }

            Resources::Validate::Region.instances(
              instances,
              permitted_keys: permitted_and_required_keys
            )
          end

          def self.instances
            Resources::Region.instances(path: ["storage", "buckets"])
          end
        end

        module Remote
          include GClouder::GSUtil

          # FIXME: make more robust(!)
          def self.list
            gsutil("ls", "-L").to_s.split("gs://").delete_if(&:empty?).each_with_object({}) do |data, collection|
              normalized = data.split("\n").map! { |b| b.delete("\t") }
              bucket_name = normalized[0].delete("/ :")
              region = normalized.select { |e| e.match("^Location constraint:") }.last.split(":").last.downcase
              collection[region] ||= []
              collection[region] << { "name" => bucket_name }
            end
          end
        end

        module Bucket
          include GClouder::GSUtil
          include GClouder::Config::CLIArgs

          def self.setDefaultAccess(bucket_name, default_access)
            info "# gsutil defacl ch -u #{default_access} gs://#{bucket_name}" if cli_args[:debug]

            return if cli_args[:dry_run]

            # Just use shell, as -p flag is not valid for 'defacl ch'.
            shell("gsutil defacl ch -u #{default_access} gs://#{bucket_name}")
          end

          def self.check_exists?(region, bucket_name)
            gsutil_exec("ls", "gs://#{bucket_name} > /dev/null 2>&1 && echo 0 || echo 1").to_i == 0
          end

          def self.ensure(region, bucket)
            if check_exists?(region, bucket["name"])
              good bucket["name"]
              return
            end

            add "#{bucket["name"]} [#{bucket["default_access"]}]"
            gsutil "mb", "-l #{region} gs://#{bucket["name"]}"


            setDefaultAccess bucket["name"], bucket["default_access"] if bucket.key?("default_access")
          end
        end
      end
    end
  end
end
