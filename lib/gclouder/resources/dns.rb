#!/usr/bin/env ruby

module GClouder
  module Resources
    module DNS
      include GClouder::GCloud
      include GClouder::Config::Project
      include GClouder::Config::CLIArgs
      include GClouder::Logging

      def self.clean
        return if undefined.empty?
        header :clean

        undefined.each do |region, zones|
          info region, indent: 2, heading: true
          zones.each do |zone|
            next unless zone.key?("records")
            info zone["name"], indent: 3, heading: true
            zone["records"].each do |record|
              warning "#{record['name']} IN A #{record['type']} #{record['ttl']} #{record['rrdatas'].join(' ')}", indent: 4
            end
          end
        end
      end

      def self.update_zone_record(zones, zone, record, key, value)
        record = zones.fetch_with_default("name", zone, {}).fetch("records", []).fetch_with_default("name", record, {})
        fatal "couldn't update zone record" if record.empty?
        record[key] = value
      end

      def self.record?(zones, zone, record)
        zones.fetch_with_default("name", zone, {}).fetch("records", []).fetch_with_default("name", record, {}).empty?
      end

      def self.zone?(zones, zone)
        zones.fetch_with_default("name", zone, {}).empty?
      end

      def self.zone_record?(zones, zone_name, record_name)
        found_zone = zones.find { |z| z["name"] == zone_name }
        return unless found_zone
        found["records"].find { |r| r["name"] == record_name }.nil?
      end

      def self.zone_records_append(zones, zone, record)
        zone = zones.fetch_with_default("name", zone, {})
        fatal "couldn't update zone" if zone.empty?
        zone["records"] << record
      end

      def self.undefined
        return {} if Remote.list.empty?

        Remote.list.each_with_object({ "global" => [] }) do |(_region, zones), collection|
          zones.each do |zone|
            # if zone isnt defined locally, then add it along with its associated records
            if !zone?(zones, zone["name"])
              collection["global"] << zone
              next
            end

            next unless zone.key?("records")

            # if record isnt defined locally, create a zone in global (if one doesn't exist), then append record to records field
            zone["records"].each do |record|
              if !zone?(collection["global"], zone["name"])
                zone_collection = zone.dup
                zone_collection["records"] = []
                collection["global"] << zone_collection
              end

              if !record?(zones, zone["name"], record["name"])
                zone_records_append(collection["global"], zone["name"], record)
              end
            end
          end
        end
      end

      def self.validate
        return if Local.list.empty?
        header :validate

        failure = false

        Local.list.each do |region, zones|
          info region, indent: 2, heading: true

          unless zones.is_a?(Array)
            failure = true
            bad "zones value should be an array", indent: 3, heading: true
            next
          end

          zones.each do |zone|
            unless zone.is_a?(Hash)
              failure = true
              bad "zone value should be a hash", indent: 3, heading: true
              next
            end

            unless zone.key?("name")
              failure = true
              bad "zone with missing key: name", indent: 3, heading: true
              next
            end

            if zone["name"] !~ /^[a-z0-9\-]+$/
              failure = true
              bad "zone name must only contain lower-case letters, digits or dashes"
              next
            end

            info zone["name"], indent: 3, heading: true

            if zone.key?("zone")
              good "resource has zone specified (#{zone['zone']})", indent: 4
            else
              failure = true
              bad "missing key: zone", indent: 4
            end

            next unless zone.key?("records")

            zone["records"].each do |record|
              info record["name"], indent: 4, heading: true
              if ["A", "CNAME", "PTR", "NS", "TXT"].include?(record["type"])
                good "record has valid type (#{record['type']})", indent: 5
              else
                bad "unknown record type: #{record['type']}", indent: 5
                failure = true
              end

              if record["ttl"].is_a?(Integer)
                good "record has valid ttl (#{record['ttl']})", indent: 5
              else
                bad "record has invalid ttl: #{record['ttl']}", indent: 5
                failure = true
              end

              if record.key?("value") || record.key?("static_ips")
                good "record has a target", indent: 5
              else
                bad "record has no target", indent: 5
                failure = true
              end
            end
          end
        end

        fatal "failure due to invalid config" if failure
      end

      def self.header(stage = :ensure)
        info "[#{stage}] dns", indent: 1, title: true
      end

      def self.ensure
        return if Local.list.empty?

        header

        Local.list.each do |region, zones|
          info region, heading: true, indent: 2

          zones.each do |zone|
            project_id = zone_project_id(zone)

            next if skip?(project_id, zone)

            info
            Zone.ensure(project_id, zone["name"], zone["zone"])
            Records.ensure(project_id, zone)
          end
        end
      end

      def self.skip?(project_id, zone)
        return false if project_id == project["project_id"]
        return false if !cli_args[:skip_cross_project_resources]

        extra_info = " [#{project_id}]" if project_id != project["project_id"]
        warning "#{zone['name']}#{extra_info} [skipping] (cross project resource)", indent: 3, heading: true
        true
      end

      def self.zone_project_id(zone_config)
        return project["project_id"] unless zone_config
        zone_config.key?("project_id") ? zone_config["project_id"] : project["project_id"]
      end

      module Zone
        include GClouder::Config::Project

        def self.ensure(project_id, name, zone)
          extra_info = (project_id != project["project_id"]) ? "[#{project_id}]" : ""

          Resource.ensure :"dns managed-zones", name,
            "--dns-name=#{zone} --description='Created by GClouder'", project_id: project_id, extra_info: extra_info
        end
      end

      module Records
        include GClouder::Logging
        include GClouder::Config::CLIArgs
        include GClouder::GCloud

        def self.ensure(project_id, zone)
          return unless zone.key?("records")

          start_transaction(project_id, zone["name"])

          zone["records"].each do |record|
            next unless record_is_valid(record)

            values = []

            if record.key?("value") && record["value"].is_a?(Array)
                values << record["value"].join(" ")

            elsif record.key?("value") && record["value"].is_a?(String)
                values << record["value"]

            elsif record.key?("static_ips")
              record["static_ips"].each do |ip|
                values << static_ip(project_id, zone["name"], ip)
              end

            else
              bad "no 'value' or 'static_ips' key found for record: #{record["name"]}"
              fatal "failure due to invalid config"
            end

            values.each do |value|
              unless record["name"].match(/\.$/)
                bad "record name missing '.' suffix: #{record["name"]}"
                fatal "failure due to invalid config"
              end
              ttl = record.key?("ttl") ? record["ttl"] : "300"
              add_record_set record["name"], value, zone["name"], record["type"], ttl, project_id
            end
          end

          execute_transaction(project_id, zone["name"])
        end

        def self.start_transaction(project_id, zone_name)
          gcloud "dns record-sets transaction start --zone=#{zone_name}", project_id: project_id
        end

        def self.execute_transaction(project_id, zone_name)
          gcloud "dns record-sets transaction execute --zone=#{zone_name}", project_id: project_id
        end

        def self.abort_transaction(args, project_id)
          info "aborting dns record-set transaction", indent: 4
          gcloud "dns record-sets transaction abort #{args}", project_id: project_id
          # FIXME: remove transaction file..
        end

        def self.record_is_valid(record)
          if record["type"] == "CNAME" && !record["value"].end_with?(".")
            info "CNAME value must end with '.'"
            return false
          end

          true
        end

        # FIXME: if a record exists but ttl or ip are different, an update should be performed
        def self.add_record_set(name, value, zone, type, ttl, project_id)
          if record_exists?(project_id, zone, name, type)
            good "#{name} IN #{type} #{value} #{ttl}", indent: 4
            return
          end

          add "#{name} IN #{type} #{value} #{ttl}", indent: 4

          gcloud "dns record-sets transaction add --name=#{name} --zone=#{zone} --type=#{type} --ttl=#{ttl} #{value}", project_id: project_id
        end

        def self.record_exists?(project_id, zone, name, type)
          Resource.resource?("dns record-sets", name, "--zone=#{zone}", filter: "name = #{name} AND type = #{type}", project_id: project_id, silent: true)
        end

        def self.lookup_ip(name, context)
          args = context == "global" ? "--global" : "--regions #{context}"
          ip = gcloud("compute addresses list #{name} #{args}", force: true)
          return false if ip.empty?
          ip[0]["address"]
        end

        def self.static_ip(project_id, zone_name, static_ip_config)
          %w(name context).each do |key|
            unless static_ip_config[key]
              bad "missing key '#{key}' for record"
              abort_transaction "--zone=#{zone_name}", project_id
              fatal "failure due to invalid config"
            end
          end

          name = static_ip_config["name"]
          context = static_ip_config["context"]

          ip = lookup_ip(name, context)

          unless ip
            unless cli_args[:dry_run]
              bad "ip address not found for context/name: #{context}/#{name}"
              abort_transaction "--zone=#{zone_name}", project_id
              fatal "failure due to invalid config"
            end

            # on dry runs assume the ip address has not been created but config is valid
            ip = "<#{context}/#{name}>"
          end

          ip
        end

        def self.describe_zone(project_id, zone_name)
          gcloud "--format json dns managed-zones describe #{zone_name}", project_id: project_id, force: true
        end

        def self.zone_nameservers(project_id, zone_name)
          remote_zone_definition = describe_zone(project_id, zone_name)
          fatal "nameservers not found for zone: #{zone_name}" unless remote_zone_definition.key?("nameServers")
          remote_zone_definition["nameServers"]
        end

        def self.dependencies
          return unless project.key?("dns")
          return unless project["dns"].key?("zones")

          project["dns"]["zones"].each do |zone, zone_config|
            project_id = zone_project_id(zone_config)
            zone_name  = zone.tr(".", "-")

            # skip zone unless manage_nameservers is true
            next unless zone_config.key?("manage_nameservers")
            next unless zone_config["manage_nameservers"]

            # parent zone data
            parent_zone = zone.split(".")[1..-1].join(".")
            parent_zone_name = parent_zone.tr(".", "-")

            parent_zone_config = project["dns"]["zones"][parent_zone]

            # get project_id for parent zone - if it isn't set then assume the zone exists in current project
            parent_project_id = parent_zone_config.key?("project_id") ? parent_zone_config["project_id"] : project_id

            info "ensuring nameservers for zone: #{zone}, project_id: #{parent_project_id}, parent_zone: #{parent_zone}"

            next if cli_args[:dry_run]

            # find nameservers for this zone
            nameservers = zone_nameservers(project_id, zone_name)

            # ensure parent zone exists
            create_zone(parent_project_id, parent_zone, parent_zone_name)

            # create nameservers in parent zone
            start_transaction(parent_project_id, parent_zone_name)
            add_record_set zone, nameservers.join(" "), parent_zone_name, "NS", 600, parent_project_id
            execute_transaction(parent_project_id, parent_zone_name)
          end
        end
      end

      module Local
        def self.list
          GClouder::Resources::Global.instances(path: %w(dns zones))
        end
      end

      module Remote
        def self.list
          zones.each_with_object({ "global" => [] }) do |zone, collection|
            collection["global"] << { "name" => zone["name"], "records" => records(zone["name"]) }
          end.delete_if { |_k, v| v.empty? }
        end

        def self.records(zone_name)
          Resource.list("dns record-sets", "--zone #{zone_name}")
        end

        def self.zones
          Resource.list("dns managed-zones").map { |zone| zone }
        end
      end
    end
  end
end
