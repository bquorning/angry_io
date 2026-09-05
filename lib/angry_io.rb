# frozen_string_literal: true

require "stringio"
require_relative "angry_io/version"

module AngryIo
  # An IO that raises when you write to it, so tests can't silently pollute
  # stdout/stderr. Zero-byte writes like `$stderr.print("")` emit nothing and
  # are allowed; anything that would produce output raises an IOError.
  class Stream < StringIO
    def initialize
      super(+"")
    end

    # StringIO's print, puts, printf, <<, syswrite and write_nonblock all
    # funnel through #write, so this one guard catches them.
    def write(*strings)
      strings.each do |string|
        next if string.to_s.empty?

        raise IOError, "AngryIo::Stream is not writable: #{string.to_s.inspect}"
      end
      super
    end

    # StringIO#putc writes directly in C, bypassing #write. It always emits a
    # byte, so it always refuses.
    def putc(char)
      raise IOError, "AngryIo::Stream is not writable: #{char.inspect}"
    end
  end

  Config = Struct.new(:enabled) do
    def initialize
      self.enabled = -> { true }
    end
  end

  @config = Config.new

  class << self
    attr_reader :config

    def configure
      yield @config
    end

    # Swap $stdout and $stderr to AngryIo::Stream instances around the given
    # block, restoring them (and closing the buffers) in an ensure. No-ops when
    # +opted_out+ is true or when +config.enabled+ returns false, so the block
    # runs untouched.
    def around_streams(opted_out: false)
      return yield if opted_out
      return yield unless config.enabled.call

      original_stdout = $stdout
      original_stderr = $stderr
      stdout_buffer = Stream.new
      stderr_buffer = Stream.new
      $stdout = stdout_buffer
      $stderr = stderr_buffer

      begin
        yield
      ensure
        $stdout = original_stdout
        $stderr = original_stderr
        stdout_buffer.close
        stderr_buffer.close
      end
    end
  end
end
