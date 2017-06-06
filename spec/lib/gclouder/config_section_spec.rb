#!/usr/bin/env ruby

require "gclouder"
require "spec_helper"

describe GClouder::ConfigSection do
  describe "#find" do
    context "when called with non-array path" do
      it "it raises an error" do
        expect { GClouder::ConfigSection.find("", {}) }.to raise_error(StandardError)
      end
    end

    context "when called with non-hash data" do
      it "it raises an error" do
        expect { GClouder::ConfigSection.find([], "") }.to raise_error(StandardError)
      end
    end

    context "when called with a valid path, and valid data" do
      it "it returns section" do
        expect(GClouder::ConfigSection.find([ :a, :b ], { :a => { :b => "test" } })).to eq("test")
      end
    end

    context "when called with a invalid path, and valid data" do
      before { allow($stdout).to receive(:write) }

      it "it raises an error" do
        expect { GClouder::ConfigSection.find([ :b, :c ], { :a => { :b => "test" } }) }.to raise_error(SystemExit)
      end
    end

    context "when called with a invalid path, and valid data, with silent flag" do
      it "it raises an error" do
        expect(GClouder::ConfigSection.find([ :b, :c ], { :a => { :b => "test" } }, silent: true)).to eq(false)
      end
    end
  end
end
