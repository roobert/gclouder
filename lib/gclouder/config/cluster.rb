#!/usr/bin/env ruby

module GClouder
  module Config
    class Cluster < DeepMergeHash
      def context(context)
        dup = self.dup

        permitted_keys = case context
        when :create_cluster
          [
            "additional_zones",
            "async",
            "cluster_ipv4_cidr",
            "disable_addons",
            "disk_size",
            "no_enable_cloud_endpoints",
            "no_enable_cloud_logging",
            "no_enable_cloud_monitoring",
            "image_type",
            "machine_type",
            "max_nodes_per_pool",
            "network",
            "num_nodes",
            "password",
            "scopes",
            "subnetwork",
            "username",
            "wait",
            "zone",
          ]
        when :create_nodepool
          # flip value due to differing key name..
          if self.key?("no_enable_cloud_endpoints")
            dup[:enable_cloud_endpoints] = self[:no_enable_cloud_endpoints] ? false : true
          end

          [
            "disk_size",
            "enable_cloud_endpoints",
            "image_type",
            "machine_type",
            "num_nodes",
            "scopes",
            "zone",
            "cluster",
          ]
        when :resize_cluster
          dup["size"] = self["num_nodes"] if self.key?("num_nodes")

          [
            "async",
            "size",
            "wait",
            "zone",
            "node_pool",
          ]
        else
          raise StandardError, "invalid context supplied when querying config object: #{context}"
        end

        dup.delete_if { |k, _| !permitted_keys.include?(k) }
      end
    end
  end
end
