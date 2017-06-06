#!/usr/bin/env ruby
#
# NOTE
#
# table of equivalent commands for `gcloud container ...` commands..
#
# convert node-pool parameters to cluster create and cluster resize parameters..
#
# clusters create            - clusters resize - nodepool create
#
# additional-zones           -                 -
# async                      - async           -
# cluster-ipv4-cidr          -                 -
# disable-addons             -                 -
# disk-size                  -                 - disk-size
# no-enable-cloud-endpoints  -                 - enable-cloud-endpoints
# no-enable-cloud-logging    -                 -
# no-enable-cloud-monitoring -                 -
# image-type                 -                 - image-type
# machine-type               -                 - machine-type
# max-nodes-per-pool         -                 -
# network                    -                 -
# num-nodes                  - size            - num-nodes
# password                   -                 -
# scopes                     -                 - scopes
# subnetwork                 -                 -
# username                   -                 -
# wait                       - wait            -
# zone                       - zone            - zone
# -                          -                 - cluster
# -                          - node-pool       - -
#

module GClouder
  module Resources
    module Container
      module Clusters
        include GClouder::Logging
        include GClouder::Config::Project
        include GClouder::Resource::Cleaner

        module Config
          def self.merged(config)
            return unless config.key?("regions")
            config["regions"].each do |region, region_config|
              next unless region_config.key?("clusters")

              region_config["clusters"].each_with_index do |cluster, cluster_index|
                cluster_config = config["regions"][region]["clusters"][cluster_index]
                config["regions"][region]["clusters"][cluster_index] = GClouder::Config::Cluster.new(cluster_config)

                config["regions"][region]["clusters"][cluster_index]["node_pools"].each_with_index do |pool, pool_index|
                  pool_config = config["regions"][region]["clusters"][cluster_index]["node_pools"][pool_index]
                  config["regions"][region]["clusters"][cluster_index]["node_pools"][pool_index] = GClouder::Config::Cluster.new(pool_config)
                end
              end
            end

            config
          end
        end

        def self.header(stage = :ensure)
          info "[#{stage}] container / clusters", title: true
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
            region_config.each do |cluster|
              info
              Cluster.build(region, cluster)
            end
          end
        end

        module Local
          def self.list
            Resources::Region.instances(path: section)
          end

          def self.section
            ["clusters"]
          end

          def self.validate
            Resources::Validate::Region.instances(
              list,
              required_keys:  GClouder::Config::Arguments.required(["container", "clusters"]),
              permitted_keys: GClouder::Config::Arguments.permitted(["container", "clusters"]),
              # FIXME: zone has wrong type in assets arguments file
              # FIXME: num_nodes has wrong type in assets arguments file
              ignore_keys: %w(node_pools zone num_nodes),
            )
          end
        end

        module Remote
          def self.list
            Resources::Remote.instances(
              path: %w(container clusters),
              # FIXME: zone has wrong type in assets arguments file
              # FIXME: num_nodes has wrong type in assets arguments file
              ignore_keys: %w(node_pools zone num_nodes),
            )
          end
        end

        module Cluster
          include GClouder::Shell
          include GClouder::Logging
          include GClouder::Config::CLIArgs
          include GClouder::Helpers
          include GClouder::GCloud

          def self.build(region, cluster)
            unless cluster["zone"]
              info "skipping cluster since no zone is set"
              return
            end

            config = cluster.context(:create_cluster)

            create(cluster["name"], config)

            #check_immutable_conflicts(cluster)
          end

          #def self.check_immutable_conflicts(cluster)
          #  check_immutable_cluster_conflicts(cluster)
          #  check_immutable_nodepool_conflicts(cluster)
          #end

          #def self.check_immutable_cluster_conflicts(cluster)
          #  return unless Resource.resource?("container clusters", cluster["name"], silent: true)

          #  #info "checking cluster for immutable resource conflicts: #{cluster}"

          #  zone = cluster["zone"]

          #  remote_cluster_config = get_remote_cluster_config(cluster, zone)

          #  immutable_parameters = %w(cluster_ipv4_cidr current_node_count instance_group_urls locations
          #                            node_pools services_ipv4_cidr username password name zone additional_zones network
          #                            subnetwork node_config)

          #  cluster_config.each do |cluster_key, cluster_value|
          #    next if cluster_key == "node_pools"

          #    unless immutable_parameters.include?(cluster_key)
          #      #debug "skipping key since it isn't immutable: #{cluster_key}"
          #      next
          #    end

          #    if cluster_key == "additional_zones"
          #      remote_value = remote_cluster_config["locations"].sort
          #      cluster_value = [cluster_value + [cluster_config["zone"]]].flatten.sort
          #    else
          #      remote_value = remote_cluster_config[cluster_key.mixedcase]
          #    end

          #    check_values(cluster_key, remote_value, cluster_value)
          #  end
          #end

          #def self.check_immutable_nodepool_conflicts(cluster)
          #  intersection = nodepool_intersection(cluster)

          #  return if intersection.empty?

          #  #info "checking nodepools for immutable resource conflicts: #{intersection.join(", ")}"

          #  intersection.each do |pool|
          #    #debug "checking pool: #{pool}"

          #    zone = pool["zone"]

          #    pool.each do |pool_key, pool_value|
          #      immutable_parameters = %w(initial_node_count disk_size_gb service_account image_type machine_type scopes)

          #      # these keys are exposed through the pool resource but should be skipped..
          #      next if pool_key == "zone"
          #      next if pool_key == "additional_zones"

          #      unless immutable_parameters.include?(pool_key)
          #        #debug "skipping key since it isn't immutable: #{pool_key}"
          #        next
          #      end

          #      remote_nodepool_config = get_remote_nodepool_config(cluster["name"], pool["name"], zone)

          #      if pool_key == "scopes"
          #        check_values(pool_key, remote_nodepool_config["config"]["oauthScopes"], pool_value.sort)
          #        next
          #      end

          #      check_values(pool_key, remote_nodepool_config["config"][pool_key.mixedcase], pool_value)
          #    end
          #  end
          #end

          #def self.nodepool_intersection(cluster)
          #  zone = cluster["zone"]
          #  remote_nodepool_names(cluster["name"], zone) & local_nodepool_names(cluster)
          #end

          #def self.local_nodepool_names(cluster)
          #  cluster["node_pools"].map { |pool| pool["name"] }
          #end

          #def self.remote_nodepool_names(cluster_name, zone)
          #  gcloud("--format json container clusters describe #{cluster_name} --zone #{zone} | jq -r '.nodePools[].name'", force: true).split("\n")
          #end

          #def self.get_remote_nodepool_config(cluster_name, pool, zone)
          #  filter = "jq -r '.nodePools[] | select(.name == \"#{pool}\")'"
          #  gcloud("--format json container clusters describe #{cluster_name} --zone #{zone} | #{filter}", force: true)
          #end

          #def self.get_remote_cluster_config(cluster_name, zone)
          #  gcloud("--format json container clusters describe #{cluster_name} --zone #{zone}", force: true)
          #end

          #def self.check_values(key, remote_value, local_value)
          #  if  remote_value != local_value
          #    fatal "error: remote config doesn't match local config: #{key} (#{remote_value} != #{local_value})"
          #  else
          #    #debug "local and remote keys have same value for param: #{key} = #{local_value}"
          #    true
          #  end
          #end

          def self.loop_until_cluster_exists(cluster_name)
            until Resource.resource?("container clusters", cluster_name, silent: true)
              sleep 1
            end
          end

          def self.create(cluster_name, config)
            args = hash_to_args(config)
            Resource.ensure :"container clusters", cluster_name, args, indent: 3
            loop_until_cluster_exists(cluster_name) if !cli_args[:dry_run]
          end
        end
      end
    end
  end
end
