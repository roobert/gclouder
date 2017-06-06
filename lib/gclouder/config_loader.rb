#!/usr/bin/env ruby

module GClouder
  module ConfigLoader
    def self.load(path)
      data = DeepMergeHash.new
      file = File.join(File.dirname(__FILE__), path, "**/*.yml")

      configs = Dir.glob(file)

      configs.each do |config|
        yaml = YAML.load_file config
        section_path = to_path(config, path)
        hash = section_path.reverse.inject(yaml) { |value, key| { key => value } }
        data = data.deep_merge hash
      end

      data
    end

    def self.to_path(config, path)
      config.gsub(/.*#{path}\//, "").gsub!(/\.yml$/, "").split("/")
    end
  end
end
