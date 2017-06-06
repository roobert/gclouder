#!/usr/bin/env ruby

require "open3"

module GClouder
  module Shell
    include GClouder::Logging

    def self.included(klass)
      klass.extend Shell
    end

    def shell(command, failure: true, silent: false)
      stdout, stderr, status, failed = run(command)

      if (GClouder.cli_args[:debug] || failed) && !silent
        header(command)
        dump_fds(stdout, stderr)
      end

      if !failed && silent
        return true
      end

      if failed && !failure
        return false
      end

      if failed && silent
        return false
      end

      if failed && !silent
        footer(status)
      end

      if silent
        return
      end

      stdout
    end

    private

    def header(command)
      info
      info "# #{command}"
    end

    def dump_fds(stdout, stderr)
      dump(stdout)
      dump(stderr)
    end

    def dump(fd)
      return if fd.empty?
      info fd
    end

    def footer(status)
      fatal "there was an error running the previous shell command which exited with non-0: #{status}"
    end

    def run(command)
      stdout, stderr, status = Open3.capture3(command)
      failed = status.to_i > 0
      [stdout, stderr, status, failed]
    end
  end
end
