#!/usr/bin/env ruby

module GClouder
  module Resources
    module Local
      def self.included(klass)
        klass.extend Local
      end

      # FIXME: error if path doesnt exist..
      def get_section(data, path, silent: false)
        path.each do |key|
          return [] unless data.key?(key)
          data = data[key]
        end

        data
      end
    end

    module Global
      include GClouder::Logging
      include GClouder::Config::Project
      include GClouder::Config::CLIArgs
      include Local

      def self.instances(path: [])
        data = get_section(project, path)

        return {} if data.empty?

        { "global" => data }
      end
    end

    module Region
      include GClouder::Logging
      include GClouder::Helpers
      include GClouder::Config::Project
      include GClouder::Config::CLIArgs
      include Local

      def self.instances(path: [])
        return {} unless project.key?("regions")

        data = project["regions"].each_with_object({}) do |(region, region_config), instances|
          instances[region] ||= []

          data = get_section(region_config, path, silent: true)

          data.each do |instance|
            if GClouder::Config::Defaults.section?(path)
              defaults = to_deep_merge_hash(GClouder::Config::Defaults.section(path))
              instance = defaults.deep_merge(instance)
            end

            instances[region] << instance
          end
        end

        data.delete_if { |_k, v| v.empty? }
      end
    end

    # FIXME: should this be split out into a separate module that deals with remote state?
    module Remote
      def self.instances(path: [], ignore_keys: [], skip_instances: {}, args: nil)
        resource_name = path.join(" ").to_sym

        Resource.list(resource_name, args).each_with_object({}) do |resource, collection|
          skip = false

          skip_instances.each do |key, value|
            next unless resource.key?(key)
            if resource[key] =~ value
              skip = true
              break
            end
          end

          next if skip

          YAML.load_file("assets/mappings/file.yml")

          # FIXME: this is so keys with partial matches work..
          file_mapping_key = path.join("::")
          file_mapping = YAML.load_file("assets/mappings/file.yml").fetch(file_mapping_key, nil)

          resource_representation_path = file_mapping.nil? ? path : file_mapping

          #ap GClouder::Config::ResourceRepresentations.properties

          # contains list of non-output-only remote properties
          resource_representation = GClouder::Config::ResourceRepresentations.section(resource_representation_path)

          #ap resource_representation

          # FIXME: partial key matches here are bad.. i.e: [compute, networks]  matches [compute, networks, subnetworks]
          # maps remote property names back to arguments
          property_mappings_key = path.join("::")
          property_mappings = YAML.load_file("assets/mappings/property.yml").fetch(property_mappings_key, [])

          # Assume global, unless we can find or infer a region...
          region = "global"
          region = resource["region"] if resource.key?("region")
          zone = resource["zone"] if !resource.key?("region") && resource.key?("zone")

          if resource.key?("selfLink") && resource["selfLink"].match(/zones\//) && !zone
            zone = resource["selfLink"].match(/zones\/([^\/]+)/)[1]
          end

          if zone
            resource["zone"] = zone
            region = zone.sub(/-[a-z]$/, "")
          end

          # 1: convert key names to snake_case
          resource = resource.to_snake_keys

          # 2: delete any keys not in resource_representations (because they're output only)
          # FIXME: warn about deleting keys?
          resource.delete_if do |key, _value|
            resource_representation[key] == "OutputOnly" && key != "name"
          end

          # 3: convert the names of any keys using the mappings file
          property_mappings.each do |argument, resource_representation|
            # FIXME: don't overwrite arguments..
            resource[argument] = resource.dig(*resource_representation)
            resource.delete(resource_representation)
          end

          ignore_keys.each do |key|
            next unless resource.key?(key)
            resource.delete(key)
          end

          # ?: if there are any keys *not* in the resource_representations file then we have a problem

          # ?: if there are any keys which dont match an argument, then we have a problem

          collection[region] ||= []
          collection[region] << resource
        end
      end
    end
  end
end
