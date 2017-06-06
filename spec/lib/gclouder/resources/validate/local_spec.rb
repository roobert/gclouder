#!/usr/bin/env ruby

require "logger"
require "gclouder"
require "spec_helper"

describe GClouder::Resources::Validate::Local do
  before(:each) do
    @instance = {
      "name" => "test",
      "permitted" => "value",
      "required" => "value",
    }

    @required_keys = {
      "required" => {
        "type" => "String",
        "required" => true,
      }
    }

    @unknown_key = {
      "unknown" => "value"
    }

    @permitted_keys = {
      "permitted" => {
        "type" => "String",
        "required" => true,
      }
    }

    @instance_invalid_value = {
      "permitted" => [1,2,3]
    }
  end

  describe "#has_required_keys?" do
    let(:dummy_module) { Class.new { extend GClouder::Resources::Validate::Local } }

    context "when called with an instance that has required keys" do
      it "it returns true" do
        expect(dummy_module.has_required_keys?(@instance, @required_keys, [])).to eq(true)
      end
    end

    context "when called with an instance that has no name key" do
      before { allow($stdout).to receive(:write) }

      it "it outputs appropriate message" do
        instance = @instance
        instance.delete_if { |k,_| k == "name" }

        expect(dummy_module).to receive(:bad).with("name is missing", {:indent => 3}).and_call_original
        dummy_module.has_required_keys?(instance, @required_keys, [])
      end

      it "it returns false" do
        instance = @instance
        instance.delete_if { |k,_| k == "name" }

        expect(dummy_module.has_required_keys?(instance, @required_keys, [])).to eq(false)
      end
    end

    context "when called with an instance that has a missing key and ignored_keys includes missing key name" do
      it "it returns true" do
        instance = @instance
        instance.delete_if { |k,_| k == "required" }

        dummy_module.has_required_keys?(instance, @required_keys, ["required"])
      end
    end
  end

  describe "#has_unknown_keys?" do
    let(:dummy_module) { Class.new { extend GClouder::Resources::Validate::Local } }

    context "when called with an instance that has only permitted keys" do
      before { allow($stdout).to receive(:write) }

      it "it returns false" do
        instance = @instance
        instance.delete_if { |k,_| k == "required" }

        expect(dummy_module.has_unknown_keys?(instance, @permitted_keys, [])).to eq(false)
      end
    end

    context "when called with an instance that contains a non-permitted key that is listed in ignore_keys" do
      before { allow($stdout).to receive(:write) }

      it "it returns false" do
        expect(dummy_module.has_unknown_keys?(@instance, @permitted_keys, ["required"])).to eq(false)
      end
    end

    context "when called with an instance that contains an unknown key" do
      before { allow($stdout).to receive(:write) }

      it "it outputs appropriate message" do
        expect(dummy_module).to receive(:bad).with("required is an invalid key", {:indent => 4}).and_call_original
        dummy_module.has_unknown_keys?(@instance, @permitted_keys, [])
      end

      it "it returns true" do
        expect(dummy_module.has_unknown_keys?(@instance, @permitted_keys, [])).to eq(true)
      end
    end

    context "when called with an instance that contains a key with an invalid value" do
      before { allow($stdout).to receive(:write) }

      it "it outputs appropriate message" do
        expect(dummy_module).to receive(:bad).with("permitted invalid type: Array (should be: String)", {:indent => 4}).and_call_original
        dummy_module.has_unknown_keys?(@instance_invalid_value, @permitted_keys, [])
      end

      it "it returns true" do
        expect(dummy_module.has_unknown_keys?(@instance_invalid_value, @permitted_keys, [])).to eq(true)
      end
    end
  end
end
