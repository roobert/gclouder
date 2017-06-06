#!/usr/bin/env ruby

require "stringio"
require "logger"

module GClouder
  module Logging
    class << self
      attr_accessor :appenders
    end

    @@good    ||= 0
    @@bad     ||= 0
    @@add     ||= 0
    @@change  ||= 0
    @@remove  ||= 0
    @@warning ||= 0

    def self.loggers
      @loggers ||= setup
    end

    def self.included(klass)
      klass.extend Logging
    end

    def self.setup
      appenders.map do |appender|
        appender[:appender].formatter = appender[:format]
        appender[:appender].level = Logger::DEBUG
        appender[:appender]
      end
    end

    def self.log(message, level: :info, indent: 0, heading: false, title: false)
      loggers.each do |log|
        message = case message
        when "" || nil
          [ "" ]
        when String
          message.split("\n")
        when Array
          message
        else
          fatal "unknown message type: #{message.class}"
        end

        message = [ "", "" ] + message if title
        message = [ "" ] + message if heading

        if title
          prefix = "  " * 1
        else
          prefix = "  " * indent
        end

        message.each { |line| log.send(level, prefix + line) }
      end
    end

    def self.appenders
      @appenders ||= [Appenders.stdout, Appenders.file]
    end

    module Appenders
      def self.stdout
        {
          appender: ::Logger.new(STDOUT),
          format: proc { |_, _, _, message| "#{message}\n" }
        }
      end

      def self.file
        {
          appender: ::Logger.new(File.join(File.dirname(__FILE__), "../../log.txt")),
          format: proc { |severity, datetime, _, message| "#{severity} - #{datetime}: #{message}\n" }
        }
      end

      def self.stringio(obj = StringIO.new)
        {
          appender: ::Logger.new(StringIO.new),
          format: proc { |severity, datetime, _, message| "#{severity} - #{datetime}: #{message}\n" }
        }
      end
    end

    def debug(message = "")
      Logging.log message, level: :debug
    end

    def info(message = "", indent: 0, heading: false, title: false)
      Logging.log message, level: :info, indent: indent, heading: heading, title: title
    end

    def warn(message = "", heading: false)
      Logging.log message, level: :warn, heading: heading
    end

    def error(message = "", heading: false)
      Logging.log message, level: :error, heading: heading
    end

    def fatal(message = "", status: 1, heading: false)
      Logging.log "\n#{message}", level: :fatal, heading: heading
      exit status
    end

    def resource_state(message, indent: 0, heading: false, level: :info)
      Logging.log "#{'  ' * indent}#{message}", level: level, heading: heading
    end

    def good(message, indent: 3, heading: false)
      @@good += 1
      resource_state("#{Symbols.tick} #{message}", indent: indent, heading: heading)
    end

    def bad(message, indent: 3, heading: false)
      @@bad += 1
      resource_state("#{Symbols.x} #{message}", indent: indent, heading: heading)
    end

    def add(message, indent: 3, heading: false)
      @@add += 1
      resource_state("#{Symbols.plus} #{message}", indent: indent, heading: heading)
    end

    def change(message, indent: 3, heading: false)
      @@change += 1
      resource_state("#{Symbols.o} #{message}", indent: indent, heading: heading)
    end

    def remove(message, indent: 3, heading: false)
      @@remove += 1
      resource_state("#{Symbols.minus} #{message}", indent: indent, heading: heading)
    end

    def warning(message, indent: 3, heading: false)
      @@warning += 1
      resource_state("#{Symbols.bang} #{message}", indent: indent, heading: heading)
    end

    module Symbols
      def self.tick
        "✓".green
      end

      def self.x
        "✗".red
      end

      def self.plus
        "+".blue
      end

      def self.o
        "o".yellow
      end

      def self.minus
        "-".red
      end

      def self.bang
        "!".yellow
      end
    end

    def self.report
      Logging.log "\n\n  [report]"
      Logging.log " "
      Logging.log "    #{Symbols.tick} - #{@@good}"
      Logging.log "    #{Symbols.bang} - #{@@warning}"
      Logging.log "    #{Symbols.x} - #{@@bad}"
      Logging.log " "
      Logging.log "    #{Symbols.plus} - #{@@add}"
      Logging.log "    #{Symbols.o} - #{@@change}"
      Logging.log "    #{Symbols.minus} - #{@@remove}"
    end
  end
end
