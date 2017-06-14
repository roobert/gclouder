#!/usr/bin/env ruby

require "awesome_print"
require "json"
require "yaml"
require "ipaddr"
require "trollop"
require "hashie"
require "pp"
require "colorize"

require "gclouder/logging"

require "gclouder/helpers"
require "gclouder/shell"

require "gclouder/monkey_patches/hash"
require "gclouder/monkey_patches/array"
require "gclouder/monkey_patches/string"
require "gclouder/monkey_patches/boolean"
require "gclouder/monkey_patches/ipaddr"

require "gclouder/header"

require "gclouder/config_loader"
require "gclouder/config_section"
require "gclouder/config/cli_args"
require "gclouder/config/files/project"
require "gclouder/config/cluster"
require "gclouder/config/project"
require "gclouder/config/arguments"
require "gclouder/config/defaults"
require "gclouder/config/resource_representations"

require "gclouder/mappings/file"
require "gclouder/mappings/argument"
require "gclouder/mappings/property"
require "gclouder/mappings/resource_representation"

require "gclouder/gcloud"
require "gclouder/gsutil"
require "gclouder/dependencies"
require "gclouder/resource"
require "gclouder/resource_cleaner"
require "gclouder/resources"
require "gclouder/resources/validate/local.rb"
require "gclouder/resources/validate/region.rb"
require "gclouder/resources/validate/remote.rb"
require "gclouder/resources/validate/global.rb"

require "gclouder/resources/project_id"

require "gclouder/resources/project"
require "gclouder/resources/project/iam_policy_binding.rb"

require "gclouder/resources/storage/buckets"
require "gclouder/resources/storage/notifications"

require "gclouder/resources/compute/networks"
require "gclouder/resources/compute/networks/subnets"
require "gclouder/resources/compute/routers"
require "gclouder/resources/compute/addresses"
require "gclouder/resources/compute/vpns"
require "gclouder/resources/compute/bgp-vpns"

require "gclouder/resources/compute/project_info/ssh_keys"

require "gclouder/resources/dns"

require "gclouder/resources/compute/disks"
require "gclouder/resources/compute/instances"

require "gclouder/resources/container/clusters"
require "gclouder/resources/container/node_pools"

require "gclouder/resources/compute/firewall_rules"

require "gclouder/resources/pubsub/topics"
require "gclouder/resources/pubsub/subscriptions"

require "gclouder/resources/logging/sinks"

module GClouder
  include GClouder::Logging
  include GClouder::Config::CLIArgs
  include GClouder::Config::Project
  include GClouder::Config::Arguments

  def self.run
    setup

    begin
      header
      bootstrap
      check_project_exists
      update
      report
      footer
    rescue => error
      raise error if cli_args[:trace] || cli_args[:debug]
      fatal error.message
    ensure
      Project::ID.rescue
    end
  end

  private

  def self.check_project_exists
    # FIXME: this requires Cloud Resource Manager API to be enabled for project
    return if Resources::Project.exists?
    fatal "\nerror: project does not exist or you do not have permission to access it: #{project['project_id']}"
  end

  def self.header
    info GClouder::Header.display
  end

  def self.footer
    info
  end

  def self.setup
    Dependencies.check
    Config::CLIArgs.load
    Config::Project.load
    Project::ID.load
    Config::Arguments.load
    Config::ResourceRepresentations.load
  end

  def self.bootstrap
    return unless cli_args[:bootstrap]

    Resources::Project.update

    report
    footer
    exit
  end

  # resources are ordered in an attempt to avoid dependency issues
  def self.resources
    [
      {
        name: "sinks",
        module: Resources::Logging::Sinks,
        skip: [ :check, :clean ],
      },

      {
        name: "iam",
        module: Resources::Project::IAMPolicyBinding,
        skip: [ :check ],
      },

      {
        name: "ssh-keys",
        module: Resources::Compute::ProjectInfo::SSHKeys,
        skip: [ :check, :clean ],
      },

      {
        name: "storage-buckets",
        module: Resources::Storage::Buckets,
        skip: [ :check ],
      },

      {
        name: "storage-notifications",
        module: Resources::Storage::Notifications,
        skip: [ :check, :clean ],
      },

      {
        name: "networks",
        module: Resources::Compute::Networks,
        skip: [ :check ],
      },

      {
        name: "subnets",
        module: Resources::Compute::Networks::Subnets,
        skip: [ :check ],
      },

      {
        name: "routers",
        module: Resources::Compute::Routers,
        skip: [ :check ],
      },

      {
        name: "addresses",
        module: Resources::Compute::Addresses,
      },

      {
        name: "dns",
        module: Resources::DNS,
        skip: [ :check ],
      },

      {
        name: "vpns",
        module: Resources::Compute::VPNs,
        skip: [ :check ],
      },

      {
        name: "bgp-vpns",
        module: Resources::Compute::BGPVPNs,
        skip: [ :check ],
      },

      {
        name: "vms",
        module: Resources::Compute::Instances,
      },

      {
        name: "disks",
        module: Resources::Compute::Disks,
        skip: [ :check ],
      },

      {
        name: "clusters",
        module: Resources::Container::Clusters,
        skip: [ :check ],
      },

      {
        name: "node-pools",
        module: Resources::Container::NodePools,
        skip: [ :check ],
      },

      {
        name: "firewalls",
        module: Resources::Compute::FirewallRules,
        skip: [ :check ],
      },

      {
        name: "topics",
        module: Resources::PubSub::Topics,
        skip: [ :check ],
      },

      {
        name: "subscriptions",
        module: Resources::PubSub::Subscriptions,
        skip: [ :check ],
      },
    ]
  end

  def self.process?(resource)
    return true unless cli_args[:resources]

    # if resources flag is passed then check if resource was specified
    cli_args[:resources].split(',').include?(resource)
  end

  def self.skip?(resource, action)
    return true if resource.fetch(:skip, []).include?(action)
    return true if cli_args[:stages] && !cli_args[:stages].split(",").include?(action.to_s)
  end

  def self.update
    resources.each do |resource|
      next unless process?(resource[:name])

      [:validate, :ensure , :clean, :check].each do |action|
        next if skip?(resource, action)
        resource[:module].send(action)
      end
    end
  end

  def self.report
    Logging.report
  end
end
