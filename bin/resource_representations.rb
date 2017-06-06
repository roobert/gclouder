#!/usr/bin/env ruby

require "awesome_print"

require "json"
require "yaml"

require "open-uri"
require "nokogiri"
require "hashie"

pairs = %w(
  compute:instances
  compute:addresses
  compute:subnetworks
  compute:networks
  compute:routers
  compute:firewalls
  compute:vpnTunnels
  container-engine:projects.zones.clusters
  container-engine:projects.zones.clusters.nodePools
  pubsub:projects.topics
  pubsub:projects.subscriptions
  logging:projects.sinks
)

class DeepMergeHash < Hash
  include Hashie::Extensions::DeepMerge
end

def snakecase(s)
  s.gsub(/::/, "/")
   .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
   .gsub(/([a-z\d])([A-Z])/, '\1_\2')
   .tr("-", "_")
   .downcase
end

def prune_blank!(lines)
  lines.delete_if { |line| line =~ /^\s*$/ }
end

def strip_leading_whitespace(lines)
  lines.map { |line| line.gsub(/^\s+/, "") }
end

def format_name(string)
  string.gsub!("IP", "Ip")
  snakecase(string)
end

def batch(lines)
  properties = DeepMergeHash.new
  #ap lines
  lines.each_slice(3) do |batch|
    property = format_name(batch[0])
    output_only = batch[2] =~ /^\[Output Only\]/ ? true : false
    # description = batch[2].gsub(/^\[Output Only\]\s+/, "")

    type = case batch[1]
           when /^string/
             "String"
           when "bytes"
             "String"
           when "unsigned long"
             "Integer"
           when "number"
             "Integer"
           when "long"
             "Integer"
           when "integer"
             "Integer"
           when "boolean"
             "Boolean"
           when "list"
             "Array"
           when /^object/
             "Object"
           when "nested object"
             "Hash"
           when /^enum/
             "Array"
           when /^none/
             "String"
           else
             puts "# unknown type:"
             ap batch
             batch[1]
           end

    #next if output_only
    type = "OutputOnly" if output_only

    property.gsub!("[]", "")

    h = property.split(".").reverse.inject(type) do |value, key|
      { key => value }
    end

    properties = properties.deep_merge h
  end

  properties
end



pairs.each do |pair|
  section, page = pair.split(":")

  case section
  when "compute"
    site = "https://cloud.google.com/#{section}/docs/reference/latest/"
    css_identifier = "table#properties tbody"
  when "container-engine"
    site = "https://cloud.google.com/#{section}/reference/rest/v1/"
    css_identifier = "table.properties tbody"
  when "pubsub"
    site = "https://cloud.google.com/#{section}/docs/reference/rest/v1/"
    css_identifier = "table.properties tbody"
  when "logging"
    site = "https://cloud.google.com/#{section}/docs/reference/v2/rest/v2/"
    css_identifier = "table.properties tbody"
  else
    puts "unknown section: #{section}"
    exit 1
  end

  puts "#{section} / #{page}"
  uri = URI.join(site, page)

  begin
    doc = Nokogiri::HTML(open(uri))
  rescue => e
    puts "failed to fetch: #{uri}"
    puts e
    exit 1
  end

  # remove lists which break batching
  doc.css("ul").remove

  tables = doc.css(css_identifier)
  text = case tables.length
  when 1
    doc.css(css_identifier).inner_text
  else
    doc.css(css_identifier)[1].inner_text
  end

  lines = text.split("\n")

  prune_blank!(lines)
  lines = strip_leading_whitespace(lines)

  properties = batch(lines)

  FileUtils.mkdir_p("assets/resource_representations/#{section}")
  File.open("assets/resource_representations/#{section}/#{page}.yml", "w") { |file| file.write properties.to_yaml.gsub!(/^---.*$/, "---") }
end
