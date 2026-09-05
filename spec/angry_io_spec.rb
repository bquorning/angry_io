# frozen_string_literal: true

require "logger"

# Created at load time, before any example runs — a logger holding a reference
# to the real $stdout must still be guarded.
BOOT_LOGGER = Logger.new($stdout)

RSpec.describe AngryIO do
  # The RSpec adapter (loaded in spec_helper) wraps every example, so the
  # guard is armed for the duration of this example.
  it "arms the guard during the example" do
    expect(AngryIO.armed?).to be(true)
  end

  it "raises on write, after letting the output through" do
    expect { $stdout.write("bang") }.to raise_error(IOError, /\$stdout.*bang/)
  end

  it "raises on puts" do
    expect { $stdout.puts "x" }.to raise_error(IOError)
  end

  it "raises on putc" do
    expect { $stdout.putc "x" }.to raise_error(IOError)
  end

  it "raises on warn" do
    expect { warn "x" }.to raise_error(IOError, /\$stderr/)
  end

  it "allows zero-byte writes" do
    $stdout.write("")
    $stdout.print("")
    $stdout.printf("")
    $stdout << ""
    $stdout.syswrite("")
    $stderr.print("")
  end

  it "does not arm when opted out", :i_absolutely_need_to_write_to_stdout do
    expect(AngryIO.armed?).to be(false)
  end

  it "raises for a logger created before the example ran" do
    expect { BOOT_LOGGER.info("sneaky") }.to raise_error(IOError, /sneaky/)
    expect { BOOT_LOGGER << "sneaky\n" }.to raise_error(IOError, /sneaky/)
  end

  describe ".enabled" do
    it "is settable and persists changes" do
      maybe = -> { rand(2) == 0 }
      AngryIO.enabled = maybe
      expect(AngryIO.enabled).to eq(maybe)
    ensure
      # Restore the default so later examples don't randomly run unarmed.
      AngryIO.enabled = -> { true }
    end
  end
end
