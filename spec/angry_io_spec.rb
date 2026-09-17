# frozen_string_literal: true

RSpec.describe AngryIO do
  it "raises on write" do
    expect { AngryIO::Stream.new.write("x") }.to raise_error(IOError)
  end

  it "raises on puts" do
    expect { AngryIO::Stream.new.puts("x") }.to raise_error(IOError)
  end

  it "raises on putc" do
    expect { AngryIO::Stream.new.putc("x") }.to raise_error(IOError)
  end

  it "allows zero-byte writes" do
    stream = AngryIO::Stream.new
    stream.write("")
    stream.print("")
    stream.printf("")
    stream << ""
    stream.syswrite("")
    expect(stream.string).to be_empty
  end

  # The RSpec adapter (loaded in spec_helper) wraps every example, so $stdout
  # is an AngryIO::Stream for the duration of this example.
  it "swaps $stdout to an AngryIO::Stream during the example" do
    expect($stdout).to be_an(AngryIO::Stream)
  end

  it "does not swap when opted out", :i_absolutely_need_to_write_to_stdout do
    expect($stdout).not_to be_an(AngryIO::Stream)
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

    it "restores the AngryIO::Stream afterwards" do
      expect { system("true") }.to output("").to_stdout_from_any_process
      expect($stdout).to be_an(AngryIO::Stream)
    end
  end

  describe ".configure" do
    it "yields the config and persists changes" do
      maybe = -> { rand(2) == 0 }
      AngryIO.configure { |c| c.enabled = maybe }
      expect(AngryIO.config.enabled).to eq(maybe)
    ensure
      # Restore the default so later examples don't randomly run unswapped.
      AngryIO.configure { |c| c.enabled = -> { true } }
    end
  end
end
