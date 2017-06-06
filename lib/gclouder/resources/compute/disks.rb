#!/usr/bin/env ruby

module GClouder
  module Resources
    module Compute
      module Disks
        include GClouder::Config::CLIArgs
        include GClouder::Config::Project
        include GClouder::Logging
        include GClouder::Config::Arguments
        include GClouder::Resource::Cleaner

        def self.header(stage = :ensure)
          info "[#{stage}] compute / disks", title: true, indent: 1
        end

        def self.ensure
          return if Local.list.empty?
          header

          Local.list.each do |region, disks|
            next if disks.empty?
            info region, indent: 2, heading: true
            info
            disks.each do |disk|
              Disk.ensure(disk["name"], disk["zone"], disk["size"], disk["type"])
            end
          end
        end

        def self.check
          Remote.list.each do |region, disks|
            disks.each do |disk, config|
              local_config = Local.list[region][disk]
              next unless local_config
              next if local_config == config
              info "[compute disks] local resource definition differs from immutable remote resource: #{disk}"
              info "# local config"
              ap local_config
              info "# remote config"
              ap config
              fatal ""
            end
          end
        end

        def self.validate
          return if Local.list.empty?
          header :validate
          Local.validate
        end

        module Local
          include GClouder::Logging

          def self.section
            ["compute", "disks"]
          end

          def self.list
            Resources::Region.instances(path: %w(compute disks))
          end

          def self.validate
            Resources::Validate::Region.instances(
              list,
              required_keys:  GClouder::Config::Arguments.required(section),
              permitted_keys: GClouder::Config::Arguments.permitted(section),
              ignore_keys:    ["size"]
            )
          end
        end

        module Remote
          def self.list
            vm_disk_pattern = GClouder::Resources::Compute::Instances::Local.instance_names.map{ |disk| "^#{disk}$" }.join("|")

            Resources::Remote.instances(
              path:           ["compute", "disks"],
              skip_instances: { "name" => /^gke|#{vm_disk_pattern}/ },
            )
          end
        end

        module Disk
          include GClouder::Resource

          def self.ensure(disk, zone, size, type)
            Resource.ensure :"compute disks", disk, "--zone #{zone} --size #{size} --type #{type}"
          end

          def self.purge(disk, args)
            Resource.purge :"compute disks", disk, args
          end
        end
      end
    end
  end
end
