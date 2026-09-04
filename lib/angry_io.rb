# frozen_string_literal: true

require "stringio"
require_relative "angry_io/version"

module AngryIo
  # An IO that raises when you write to it, so tests can't silently pollute
  # stdout/stderr. Backed by a frozen empty string, which makes StringIO
  # refuse writes with an IOError ("not opened for writing").
  class Stream < StringIO
    def initialize
      super(-"")
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
