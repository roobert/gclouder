#!/usr/bin/env ruby

require "gclouder"
require "spec_helper"

describe GClouder::Shell do
  describe "#shell" do
    let(:dummy_module) { Class.new { extend GClouder::Shell } }

    context "when called with a command that exits with 0" do
      it "it returns a string" do
        expect(dummy_module.shell("/bin/echo -n test")).to eq("test")
      end
    end

    context "when called with a command that exits with 0 and silent set to true" do
      it "it returns true" do
        expect(dummy_module.shell("/bin/echo -n test", silent: true)).to eq(true)
      end
    end

    context "when called with a command that exits with 0 and failure set to true" do
      it "it returns a string" do
        expect(dummy_module.shell("/bin/echo -n test", failure: true)).to eq("test")
      end
    end

    context "when called with a command that exits with 1 and failure set to true" do
      before { allow($stdout).to receive(:write) }

      it "it raises an error" do
        expect { dummy_module.shell("/bin/false", failure: true) }.to raise_error(SystemExit)
      end
    end

    context "when called with a command that exits with 1 and failure set to false" do
      before { allow($stdout).to receive(:write) }

      it "it returns false" do
        expect(dummy_module.shell("/bin/echo -n test; false", failure: false)).to eq(false)
      end
    end

    context "when called with a command that exits with 1 and silent set to true" do
      it "it returns false" do
        expect(dummy_module.shell("/bin/echo -n test; false", silent: true)).to eq(false)
      end
    end

    context "when called with a command that exits with 1 and silent set to false" do
      before { allow($stdout).to receive(:write) }

      it "it should raise an error" do
        expect { dummy_module.shell("/bin/echo -n test; false", silent: false) }.to raise_error(SystemExit)
      end
    end
  end
end
