#!/usr/bin/env ruby

module GClouder
  module Dependencies
    def self.check
      %w(jq gcloud gsutil).each do |command|
        (puts "missing dependency: #{command}"; exit 1) unless system("which #{command} > /dev/null 2>&1")
      end
    end
  end
end
