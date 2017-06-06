#!/usr/bin/env ruby

module GClouder
  module Resources
    module Compute
      module Instances
        include GClouder::Helpers
        include GClouder::Logging
        include GClouder::Config::CLIArgs

        def self.header(stage = :ensure)
          info "[#{stage}] compute / instance", indent: 1, title: true
        end

        def self.validate
          return if Local.list.empty?
          header :validate
          Local.validate
        end

        def self.ensure
          return if Local.list.empty?
          header

          Local.list.each do |region, instances|
            next if instances.empty?
            info region, indent: 2, heading: true
            info
            instances.each do |instance|
              Instance.ensure(instance["name"], hash_to_args(instance))
            end
          end
        end

        def self.check
          return if Remote.list.empty?
          return if Local.list.empty?
          header :check

          Resources::Validate::Remote.instances(
            Local.manipulated,
            Remote.list,
            skip_keys: [
              "image",
              "zone",
              "network_interfaces"
            ]
          )
        end

        def self.clean
          return if undefined.empty?
          header :clean
          undefined.each do |instance, zone|
            info zone, heading: true, indent: 2
            info
            warning "#{instance['name']} (not defined locally)"
            #Instance.purge(instance["name"], "--zone=#{zone}")
          end
        end

        def self.undefined
          Remote.list.map do |region, instances|
            return instances.map do |instance|
              next if Local.list.fetch(region, []).select {|i| i["name"] == instance["name"] }.length > 0
              zone = Resource::Find.zone(:"compute instances", instance["name"], region)
              [instance, zone]
            end.clean
          end
        end

        module Local
          include GClouder::Resources

          def self.section
            %w(compute instances)
          end

          def self.list
            Resources::Region.instances(path: section)
          end

          def self.instance_names
            list.map { |region, instances| instances.each.map { |instance| instance["name"] } }.flatten
          end

          def self.validate
            Resources::Validate::Region.instances(
              list,
              required_keys:  GClouder::Config::Arguments.required(section),
              permitted_keys: GClouder::Config::Arguments.permitted(section),
            )
          end

          def self.mappings
            Mappings::Property.section(["compute::instances", "subnet"])
          end

          def self.create_from_mapping(mappings, value)
            mappings.reverse.inject(value) { |obj, key| key.is_a?(Integer) ? [obj] : { key => obj } }
          end

          # manipulate local resources so they're comparable with remote..
          #
          # FIXME
          # this could be automated:
          # * iterate over compute::instaces
          # * create key for each value
          # * assign config[key] to newly made key
          def self.manipulated
            list.each do |_region, resources|
              resources.each do |resource|
                data_structure = create_from_mapping(mappings, resource["subnet"])
                resource.merge! data_structure["compute"]["instances"]
                resource.delete("subnet")
                resource
              end
            end
          end
        end

        module Remote
          def self.list
            get_arguments
          end

          def self.get_arguments
            Resources::Remote.instances(
              path:           ["compute", "instances"],
              skip_instances: { "name" => /^gke/, "status" => /^TERMINATED$/ }
            )
          end
        end

        module Instance
          def self.ensure(instance, args = nil)
            Resource.ensure :"compute instances", instance, args
          end

          def self.purge(instance, args = nil)
            Resource.purge :"compute instances", instance, args
          end
        end
      end
    end
  end
end
