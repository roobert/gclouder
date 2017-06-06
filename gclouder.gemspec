$:.push File.expand_path("../lib", __FILE__)
require "gclouder/version"

Gem::Specification.new do |spec|
  spec.name                       = "gclouder"
  spec.summary                    = "Google Cloud Platform Resource Deployer"
  spec.description                = "A wrapper for gcloud(1) which creates Google Cloud Platform resources based on YAML manifests"

  spec.version                    = GClouder::VERSION

  spec.authors                    = ["Rob Wilson", "Andy Hume"]
  spec.email                      = "roobert@gmail.com"
  spec.homepage                   = "https://github.com/roobert/gclouder"

  spec.license                    = "MIT"

  spec.files                      = Dir["{lib,assets}/**/*.rb", "bin/gclouder", "*.md"]
  spec.executables                = ["gclouder"]
  spec.require_paths              = ["lib"]

  spec.add_runtime_dependency     "trollop"
  spec.add_runtime_dependency     "logging"
  spec.add_runtime_dependency     "hashie"
  spec.add_runtime_dependency     "awesome_print"
  spec.add_runtime_dependency     "netaddr"
  spec.add_runtime_dependency     "nokogiri"
  spec.add_runtime_dependency     "colorize"

  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "guard"
  spec.add_development_dependency "guard-rspec"
end
