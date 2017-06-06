#!/usr/bin/env ruby

require "gclouder"
require "spec_helper"

describe GClouder::Helpers do
  before(:all) do
    @cli_args = {
      bootstrap:                 false,
      config:                    "spec/conf/test0.yaml",
      dry_run:                   false,
      activate_service_accounts: false,
      validate:                  false,
      debug:                     false,
      help:                      false,
      config_given:              true
    }

    GClouder::Config::CLIArgs.instance_variable_set(:@cli_args, @cli_args)
    GClouder::Config::Project.load
  end

  describe "#hash_to_args" do
    let(:dummy_module) { Class.new { extend GClouder::Helpers } }

    context "when called with a hash" do
      it "it returns a String" do
        expect(dummy_module.hash_to_args({}).class).to eq(String)
      end
    end

    context "when called with non-hash" do
      it "it returns a StandardError" do
        expect { dummy_module.hash_to_args(Array) }.to raise_error(StandardError)
      end
    end

    context "when called with hash which contains name key" do
      it "it returns a string which does not contain name argument" do
        expect(dummy_module.hash_to_args({ "name" => "test" })).not_to match(/name/)
      end
    end

    context "when called with hash which contains key" do
      it "it returns a string which contains key as an argument" do
        expect(dummy_module.hash_to_args({ "test" => "" })).to match(/^--test=''$/)
      end
    end

    context "when called with hash which contains multiple a keys" do
      it "it returns a string which contains multiple arguments" do
        expect(dummy_module.hash_to_args({ "test0" => "", "test1" => "" })).to match(/^--test0='' --test1=''$/)
      end
    end

    context "when called with hash which contains key that has boolean value of true" do
      it "it returns a string which contains key as an argument with no value" do
        expect(dummy_module.hash_to_args({ "test" => true })).to match(/^--test$/)
      end
    end

    context "when called with hash which contains key that has boolean value of false" do
      it "it returns a string which contains key as an argument prefixed with: no" do
        expect(dummy_module.hash_to_args({ "test" => false })).to match(/^--no-test$/)
      end
    end

    context "when called with hash which contains value that is an array" do
      it "it returns a string which contains an argument with the value as a CSV" do
        expect(dummy_module.hash_to_args({ "test" => [1,2,3] })).to match(/^--test='1,2,3'$/)
      end
    end

    context "when called with hash which contains a key that contains underscores" do
      it "it returns a string which contains an argument which has hyphens instead of underscores" do
        expect(dummy_module.hash_to_args({ "test_underscore_replacement" => "" })).to match(/^--test-underscore-replacement=''$/)
      end
    end
  end

  describe "#valid_json?" do
    let(:dummy_module) { Class.new { extend GClouder::Helpers } }

    context "when called with json" do
      it "it returns true" do
        expect(dummy_module.valid_json?({ "test" => "test" }.to_json)).to eq(true)
      end
    end

    context "when called with non-json" do
      it "it returns false" do
        expect(dummy_module.valid_json?(Array)).to eq(false)
      end
    end
  end

  describe "#to_deep_merge_hash" do
    let(:dummy_module) { Class.new { extend GClouder::Helpers } }

    context "when called with a hash" do
      it "it returns a DeepMergeHash" do
        expect(dummy_module.to_deep_merge_hash({}).class).to eq(DeepMergeHash)
      end
    end

    context "when called with a nested hash" do
      it "it returns a DeepMergeHash" do
        expect(dummy_module.to_deep_merge_hash({ "nested_hash" => {} }).class).to eq(DeepMergeHash)
      end

      it "it returns a DeepMergeHash with a nested DeepMergeHash" do
        expect(dummy_module.to_deep_merge_hash({ "nested_hash" => {} })["nested_hash"].class).to eq(DeepMergeHash)
      end
    end

    context "when called with a hash which contains an array of hashes" do
      it "it returns a DeepMergeHash" do
        expect(dummy_module.to_deep_merge_hash({ "nested_hash" => {} }).class).to eq(DeepMergeHash)
      end

      it "it returns a DeepMergeHash with an array of DeepMergeHashes" do
        expect(dummy_module.to_deep_merge_hash({ "nested_hash" => [{}, {}, {}] })["nested_hash"][0].class).to eq(DeepMergeHash)
        expect(dummy_module.to_deep_merge_hash({ "nested_hash" => [{}, {}, {}] })["nested_hash"][1].class).to eq(DeepMergeHash)
        expect(dummy_module.to_deep_merge_hash({ "nested_hash" => [{}, {}, {}] })["nested_hash"][2].class).to eq(DeepMergeHash)
      end
    end

    context "when called with a non-hash" do
      it "it returns an error " do
        expect { dummy_module.to_deep_merge_hash([]) }.to raise_error(StandardError)
      end
    end
  end

  describe "#module_exists?" do
    let(:dummy_module) { Class.new { extend GClouder::Helpers } }

    context "when called with string describing name of module that exists" do
      it "it returns true" do
        expect(dummy_module.module_exists?("GClouder::Helpers")).to eq(true)
      end
    end

    context "when called with string describing name of module that does not exist" do
      it "it returns false" do
        expect(dummy_module.module_exists?("NonExistantModule")).to eq(false)
      end
    end

    context "when called with non-string" do
      it "it returns an error" do
        expect { dummy_module.module_exists?(Array) }.to raise_error(StandardError)
      end
    end
  end
end
