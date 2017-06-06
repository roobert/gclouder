#!/usr/bin/env ruby

require "json"

module GClouder
  module Resources
    module Container
      module NodePools
        include GClouder::Shell
        include GClouder::Logging
        include GClouder::GCloud
        include GClouder::Helpers

        def self.delete_default_nodepool
          Resource.purge :"container node-pools", "default-pool"
        end

        def self.validate
          return if GClouder::Resources::Container::Clusters::Local.list.empty?
          header :validate

          GClouder::Resources::Container::Clusters::Local.list.each do |region, clusters|
            info region, heading: true, indent: 2
            clusters.each do |cluster|
              next if cluster["node_pools"].empty?
              info cluster["name"], heading: true, indent: 3
              Local.validate(cluster)
            end
          end
        end

        def self.ensure
          return if GClouder::Resources::Container::Clusters::Local.list.empty?
          header

          GClouder::Resources::Container::Clusters::Local.list.each do |region, clusters|
            info region, heading: true, indent: 2
            clusters.each do |cluster|
              next if cluster["node_pools"].empty?
              info cluster["name"], heading: true, indent: 3
              cluster["node_pools"].each do |pool|
                NodePool.create(cluster, pool)
                NodePool.resize(cluster, pool) if Resource.resource?("container clusters", cluster["name"], silent: true)
              end
            end
          end
        end

        def self.header(stage = :ensure)
          info "[#{stage}] container / node-pools", title: true, indent: 1
        end

        # FIXME: create a collection then iterate through it to avoid printing
        # messages when no clusters are undefined
        def self.clean
          return if GClouder::Resources::Container::Clusters::Local.list.empty?
          header :clean

          GClouder::Resources::Container::Clusters::Local.list.each do |region, clusters|
            info region, heading: true, indent: 2
            clusters.each do |cluster|
              next if undefined(cluster).empty?

              info cluster["name"], heading: true, indent: 3
              undefined(cluster).each do |namespace, resources|
                resources.each do |resource|
                  message = resource['name']
                  message += " (not defined locally)"
                  info
                  warning message, indent: 4
                  #resource_purge(namespace, user)
                end
              end
            end
          end
        end

        def self.undefined(cluster)
          return {} unless Resource.resource?("container clusters", cluster["name"], silent: true)
          self::Remote.list(cluster).each_with_object({}) do |(namespace, resources), collection|
            resources.each do |resource|
              namespace_resources = self::Local.list(cluster)[namespace]

              next if namespace_resources && namespace_resources.select {|r| resource["name"] == r["name"] }.length > 0

              collection[namespace] ||= []
              collection[namespace] << resource
            end
          end
        end

        module Local
          def self.list(cluster)
            return {} unless cluster.key?("node_pools")
            { cluster["zone"].gsub(/-.$/, "") => cluster["node_pools"] }
          end

          def self.section
            %w(container node-pools)
          end

          def self.validate(cluster)
            Resources::Validate::Region.instances(
              list(cluster),
              required_keys:  GClouder::Config::Arguments.required(section).merge({ "zone" => { "type" => "String", "required" => "true" }}),
              permitted_keys: GClouder::Config::Arguments.permitted(section).merge({ "additional_zones" => { "type" => "Array", "required" => "false" } }),
              # FIXME: num_nodes has wrong type in assets arguments file..
              ignore_keys: ["size", "num_nodes"],
              skip_region: true,
              indent: 1,
            )
          end
        end

        module Remote
          def self.list(cluster)
            Resources::Remote.instances(path: %w(container node-pools), args: "--cluster #{cluster['name']} --zone #{cluster['zone']}")
          end
        end

        module NodePool
          include GClouder::Shell
          include GClouder::Logging
          include GClouder::Config::CLIArgs
          include GClouder::GCloud
          include GClouder::Helpers

          def self.create(cluster, pool)
            parameters = hash_to_args(pool.context(:create_nodepool))
            zone = pool["zone"]

            if !check_exists?(cluster["name"], pool["name"], zone)
              gcloud("alpha container node-pools create --cluster #{cluster["name"]} #{parameters} #{pool["name"]}")
              if cli_args[:dry_run]
                add pool["name"], indent: 4
              else
                sleep 1 until check_exists?(cluster["name"], pool["name"], zone)
              end
            else
              good "#{pool["name"]}", indent: 4
            end
          end

          def self.resize(cluster, pool)
            config = pool.context(:resize_cluster)
            zone = pool["zone"]

            if !check_exists?(cluster["name"], pool["name"], zone)
              info "skipping resize for non-existant cluster/nodepool: #{cluster["name"]}/#{pool["name"]}", indent: 5
              return
            end

            number_of_zones = calculate_number_of_zones(pool)

            parameters = hash_to_args(config)

            current_size = remote_size(cluster["name"], pool["name"], pool["zone"])

            desired_size = if pool.key?("additional_zones")
              config["size"] * number_of_zones
            else
              config["size"]
            end

            if desired_size != current_size
              add "resizing pool (zones: #{number_of_zones}): #{current_size} -> #{desired_size}", indent: 5
              gcloud("container clusters resize #{cluster["name"]} --node-pool #{pool["name"]} #{parameters}")
            else
              true
            end
          end

          def self.calculate_number_of_zones(pool)
            pool.key?("additional_zones") ? (pool["additional_zones"].count + 1) : 1
          end

          def self.remote_size(cluster_name, pool_name, zone)
            remote_pool_config = gcloud("--format json container clusters describe #{cluster_name} --zone #{zone} | jq --join-output -c '.nodePools[] | select(.name == \"#{pool_name}\")'", force: true)
            instance_group_ids = remote_pool_config["instanceGroupUrls"].map { |url| data = url.split("/"); [ data[-1], data[-3] ] }.to_h
            nodes = instance_group_ids.map do |instance_group_id, zone|
              gcloud("--format json compute instance-groups describe --zone #{zone} #{instance_group_id} | jq '.size'", force: true).to_i
            end
            nodes.inject(0) { |sum, i| sum + i }
          end

          def self.check_exists?(cluster_name, nodepool, zone)
            gcloud("--format json container node-pools list --zone #{zone} --cluster #{cluster_name} | jq 'select(.[].name == \"#{nodepool}\") | length'", force: true).to_i.nonzero?
          end
        end
      end
    end
  end
end
