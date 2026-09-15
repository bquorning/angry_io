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

    # `IO#reopen(io)` redirects a real $stdout/$stderr onto another IO (a
    # socket, a File, etc.) so the process's output flows there. StringIO only
    # accepts a String, so reopening onto an IO would raise
    # `TypeError: can't convert IO into StringIO` — which breaks code that
    # reopens the streams after a fork. Delegate to the original real stream we
    # replaced (which dup2's the other IO's fd onto the stdout/stderr fd,
    # surviving the caller later closing the other IO), then hand the global
    # back so subsequent writes reach the reopened IO instead of this guard.
    # Non-IO args defer to StringIO's own reopen (buffer reset).
    def reopen(other = nil, *rest)
      if other.is_a?(IO) && (swap = Thread.current.thread_variable_get(:angry_io_swap))
        real_stdout, real_stderr, stdout_buffer, stderr_buffer = swap
        if equal?(stdout_buffer)
          real_stdout.reopen(other)
          $stdout = real_stdout
        elsif equal?(stderr_buffer)
          real_stderr.reopen(other)
          $stderr = real_stderr
        else
          # Not one of the swapped buffers (a standalone Stream someone assigned
          # to $stdout outside the adapter): no original to delegate to, so match
          # StringIO and raise TypeError instead of silently no-op'ing.
          super
        end
        self
      elsif other.nil? && rest.empty?
        super() # StringIO#reopen() resets the buffer
      else
        super
      end
    end
  end

  # ActiveSupport::Testing::Stream#capture reopens $stdout/$stderr onto a
  # Tempfile and later restores them via `reopen(dup)` — a dup2-then-restore
  # pattern that only works on real IOs (Tempfile is a Delegator, and StringIO
  # can't be reopened onto one). Restore the real streams for the duration of a
  # capture/silence, the same way Minitest's capture_subprocess_io is handled.
  module ActiveSupportStreamCapture
    def capture(stream)
      AngryIo.with_real_streams { super }
    end

    def silence_stream(stream)
      # `stream` is bound at call time, so under AngryIo it's the StringIO
      # buffer — which AS can't actually reopen onto IO::NULL (it just resets
      # the buffer), leaking the block's writes to the real stream. Substitute
      # the real stream it replaced so AS silences (and the block writes to) the
      # real IO.
      real = AngryIo.real_stream_for(stream)
      AngryIo.with_real_streams { super(real || stream) }
    end

    private :capture, :silence_stream
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
      previous_swap = Thread.current.thread_variable_get(:angry_io_swap)
      Thread.current.thread_variable_set(:angry_io_swap, [original_stdout, original_stderr, stdout_buffer, stderr_buffer])

      begin
        yield
      ensure
        Thread.current.thread_variable_set(:angry_io_swap, previous_swap)
        $stdout = original_stdout
        $stderr = original_stderr
        stdout_buffer.close
        stderr_buffer.close
      end
    end

    # Run the block with the pre-swap $stdout/$stderr restored, re-swapping the
    # AngryIo::Stream buffers afterwards. Helpers like Minitest's
    # capture_subprocess_io need this: they reopen $stdout/$stderr onto
    # Tempfiles so subprocesses inherit the file descriptors, which only works
    # on real IOs. No-ops when no swap is active.
    def with_real_streams
      swap = Thread.current.thread_variable_get(:angry_io_swap)
      return yield unless swap

      real_stdout, real_stderr, stdout_buffer, stderr_buffer = swap
      $stdout = real_stdout
      $stderr = real_stderr

      begin
        yield
      ensure
        $stdout = stdout_buffer
        $stderr = stderr_buffer
      end
    end

    # If `stream` is one of the active swap's AngryIo::Stream buffers, return the
    # real stream it replaced; otherwise nil. Used by
    # ActiveSupportStreamCapture#silence_stream to redirect silencing onto the
    # real IO instead of the StringIO buffer.
    def real_stream_for(stream)
      swap = Thread.current.thread_variable_get(:angry_io_swap)
      return nil unless swap

      real_stdout, real_stderr, stdout_buffer, stderr_buffer = swap
      if stream.equal?(stdout_buffer)
        real_stdout
      elsif stream.equal?(stderr_buffer)
        real_stderr
      end
    end

    # Prepend hooks so ActiveSupport::Testing::Stream#capture / #silence_stream
    # run with the real $stdout/$stderr restored (see ActiveSupportStreamCapture).
    # No-ops when ActiveSupport isn't loaded.
    def hook_active_support_stream!
      require "active_support/testing/stream"
      ActiveSupport::Testing::Stream.prepend(ActiveSupportStreamCapture)
    rescue LoadError
      # ActiveSupport isn't available; nothing to hook.
    end
  end
end
