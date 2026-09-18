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
    expect { $stdout.write("bang") }.to raise_error(IOError, /\$stdout.*bang/m)
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

  # A raising write must flush the stream; otherwise its buffered output makes
  # a later syswrite (even a zero-byte one) trip Ruby's "syswrite for buffered
  # IO" warning, which the WarningGuard turns into a raise against an innocent
  # write. (Force sync off so the example doesn't silently go vacuous if the
  # runner ever sets $stdout.sync = true, like Minitest does.)
  it "flushes the stream when a write raises" do
    sync = $stdout.sync
    $stdout.sync = false
    expect { $stdout.write("buffered") }.to raise_error(IOError)
    $stdout.syswrite("")
  ensure
    $stdout.sync = sync
  end

  it "does not arm when opted out", :i_absolutely_need_to_write_to_stdout do
    expect(AngryIO.armed?).to be(false)
  end

  it "raises for a logger created before the example ran" do
    expect { BOOT_LOGGER.info("sneaky") }.to raise_error(IOError, /sneaky/)
    expect { BOOT_LOGGER << "sneaky\n" }.to raise_error(IOError, /sneaky/)
  end

  describe "output matcher with from_any_process" do
    it "captures subprocess stdout" do
      expect { system("echo hello") }.to output("hello\n").to_stdout_from_any_process
    end

    it "captures subprocess stderr" do
      expect { system("echo oops >&2") }.to output("oops\n").to_stderr_from_any_process
    end

    it "captures Ruby-level writes inside the block" do
      expect { $stdout.puts "hi" }.to output("hi\n").to_stdout_from_any_process
    end

    it "re-arms the guard afterwards" do
      expect { system("true") }.to output("").to_stdout_from_any_process
      expect(AngryIO.armed?).to be(true)
    end
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
