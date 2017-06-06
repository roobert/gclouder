#!/usr/bin/env ruby
#
# NOTE
#
# this is a PoC
#
# FIXME
#
# * filter out short args
# * check for commas
# * mark 'required' parameters?
# * convert symbols to types
# * only output arguments for supported resources
# * version each arguments.yaml against version of gcloud
#
# options for asserting truthiness:
# * skip any remote resource that has the same name apart from ephemeral ones
#   and accept local config changes may differ to remote truth?
# * mapping for remote resources back to config args?
# * (generate?) mapping between local and remote resource names?
# * use fuzzy mapping?
# * set of params to ignore?
#

require "awesome_print"
require "pp"
require "hashie"
require "json"
require "yaml"
require "pry"

module Boolean; end
class TrueClass; include Boolean; end
class FalseClass; include Boolean; end

class DeepMergeHash < Hash
  include Hashie::Extensions::DeepMerge
end

module GClouder
  module GCloud
    module Arguments
      def self.sections
        [
          %w(compute instances create),
          %w(compute networks create),
          %w(compute networks subnets create),
          %w(compute routers create),
          %w(compute addresses create),
          %w(compute vpn-tunnels create),
          %w(compute target-vpn-gateways create),
          %w(compute firewall-rules create),
          %w(compute disks create),
          %w(dns managed-zones create),
          %w(container clusters create),
          %w(container node-pools create),
          %w(dns record-sets transaction add),
          %w(beta pubsub topics create),
          %w(beta pubsub subscriptions create),
          %w(beta logging sinks create),
        ]
      end

      def self.update(path)
        data = DeepMergeHash.new

        Dir.glob(path).each do |page|
          next if page =~ /gcloud.1/

          path = page.split("/")[-1]
          path = path.chomp(".1")
          path = path.split("_")

          # chop off gcloud prefix
          path = path[1..-1]

          next unless sections.include?(path)

          puts "# #{path}"

          # chop off suffix create
          path = path[0..-2]

          filename = path[-1]
          dir      = path[0..-1]

          ap parse(synopsis(page))
          puts

          args = parse(synopsis(page))

          # write individual files

          FileUtils.mkdir_p("assets/arguments/#{File.dirname(path.join('/'))}")

          File.open("assets/arguments/#{File.dirname(path.join('/'))}/#{filename}.yml", "w") do |file|
            file.write args.to_yaml.gsub!(/^---.*$/, "---")
          end

          # build hash..

          h = dir.reverse.inject(args) do |a, subcommand|
            { subcommand => a }
          end

          data = data.deep_merge h
        end

        data
      end

      def self.patterns
        [/\\fR/, /\\fB/, /\\f5/, /\\fI/, "\\", "GLOBAL-FLAG ...\n", /\s+$/, /^--/, /^-/]
      end

      def self.clean(str)
        patterns.each { |pattern| str.gsub!(pattern, "") }
        str
      end

      def self.parse(synopsis)
        arguments(clean(synopsis))
      end

      def self.get_required_args(synopsis)
        # remove command
        synopsis.gsub!(/^[^A-Z]+/, "")

        # remove resource name
        synopsis.gsub!(/^[A-Z_]+/, "")

        # srip whitespace
        synopsis.strip!

        # remove optional extra resource names
        synopsis.gsub!(/^\[[A-Z_ \.]+\]/, "")
        synopsis.gsub!("...]", "")

        # srip whitespace
        synopsis.strip!

        args = {}

        # until arg list is empty..
        until synopsis == ""
          arg = synopsis.match(/^--[a-z-]+ /)
          arg = arg.to_s
          arg.strip!

          synopsis.gsub!(arg.to_s, "")

          arg.to_s.gsub!("--", "")

          parameters = synopsis.match(/(.*)--/)

          if parameters
            parameters = parameters[1]
          else
            parameters = synopsis.match(/.*/)
          end

          synopsis.gsub!(parameters.to_s, "")

          parameters.to_s.gsub!(/, -[a-z] .*/, "") if parameters

          type = case parameters.to_s
                 when nil
                   "Boolean"
                 when /[,]/
                   "Array"
                 else
                   "String"
                 end

          args[arg.to_s.gsub("--", "").tr("-", "_")] = { "type" => type, "required" => true }
        end

        args
      end

      def self.get_extra_args(extra_args)
        first_args = extra_args.scan(/\[(.*?)\](?= ) /).flatten
        last_arg = extra_args.scan(/.*\] \[(.*)\]$/).flatten

        args = first_args += last_arg

        args = args.map { |arg| arg.split(/(?=--)/) }

        args.flatten.each(&:strip!)
        args.flatten!

        args = args.map { |arg| arg.split("|") }.flatten

        args = args.map { |arg| arg.split(" ", 2) }

        arguments = {}

        args.each do |arg|
          default = arg[1].match(/default=\"([^"]+)/)[1] if arg[1] =~ /default=/
          arg[1].gsub!(/;? ?default=\"[^ ] /, "") if arg[1]
          arg[1].strip! if arg[1]
          default = Integer(default) rescue default

          arg[1].gsub!(/, -[a-z] .*/, "") if arg[1]

          type = case arg[1]
                 when nil
                   "Boolean"
                 when ""
                   "Boolean"
                 when /[,]/
                   "Array"
                 else
                   "String"
                 end

          name = arg[0].gsub(/^--/, "").tr("-", "_")

          arguments[name] = { "type" => type, "required" => false }
          arguments[name]["default"] = default if default
        end

        arguments
      end

      def self.establish_split(synopsis)
        command_and_required_args = synopsis.match(/ \[--/)

        if command_and_required_args
          offset = command_and_required_args.begin(0)

          first = synopsis[0..offset]
        else
          first = synopsis
          offset = synopsis.length
        end

        first.strip!

        second = if synopsis.length == offset
          ""
        else
           synopsis[offset..-1]
        end

        [first, second]
      end

      def self.arguments(synopsis)
        # remove uesless group
        synopsis.gsub!(" [GLOBAL-FLAG ...]", "")

        first, second = establish_split(synopsis)

        required_args = get_required_args(first)
        extra_args = get_extra_args(second)
        pp required_args
        pp extra_args

        args = required_args.merge(extra_args)
        args
      end

      def self.synopsis(file)
        synopsis = ""
        count = 0

        File.open(file).each do |line|
          count += 1 if line =~ /SYNOPSIS/
          count += 1 if count > 0

          if count == 4
            synopsis = line
            break
          end
        end
        synopsis
      end
    end
  end
end

path = ARGV[0].nil? ? "#{ENV['HOME']}/opt/google-cloud-sdk/help/man/man1/*" : File.join("#{ARGV[0]}", "/*")

#Pry::ColorPrinter.pp(GClouder::GCloud::Arguments.update(path)l)

GClouder::GCloud::Arguments.update(path).to_yaml
