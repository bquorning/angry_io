# frozen_string_literal: true

require_relative "angry_io/version"

module AngryIO
  # Prepended to the STDOUT/STDERR singletons. While armed (a test is running
  # under AngryIO.around_streams and hasn't opted out), a write goes through to
  # the real stream and *then* raises IOError — the offending output appears in
  # the test output right before the failure, so it's easy to see what printed.
  # Guarding the real stream objects, instead of swapping the globals, means
  # code that captured a reference earlier (e.g. `Logger.new($stdout)` at boot)
  # can't bypass the guard.
  module Guard
    # IO#print, puts, printf and << all funnel through #write, so this one
    # guard catches them.
    def write(*strings)
      result = super
      AngryIO.check_output!(self, strings)
      result
    end

    # syswrite and write_nonblock bypass #write, so they need their own guards.
    # Both warn ("syswrite for buffered IO") when the stream has buffered
    # output pending — and buffered output can be there without us knowing
    # (e.g. the test runner's progress dots, printed between tests while the
    # guard is unarmed). The WarningGuard would turn that warning into a raise
    # against an innocent write, so flush first while armed: the pending output
    # goes out in order, the buffer stays clean, and no warning fires.
    def syswrite(string)
      flush if AngryIO.armed?
      result = super
      AngryIO.check_output!(self, [string])
      result
    end

    def write_nonblock(string, **options)
      flush if AngryIO.armed?
      result = super
      AngryIO.check_output!(self, [string])
      result
    end

    # putc writes directly in C, bypassing #write.
    def putc(char)
      result = super
      AngryIO.check_output!(self, [char])
      result
    end

    # Reopening the stream (e.g. `$stdout.reopen(File::NULL)` after a fork) is
    # a deliberate redirect of the process's output: let it through and release
    # this stream from the guard for the rest of the test, so subsequent writes
    # reach the reopened target instead of raising. A failed reopen raises
    # before releasing, so the guard stays in place.
    #
    # `reopen(other_io)` also turns the receiver into a copy of the other IO,
    # replacing its singleton class — which strips this very module off the
    # stream. Re-prepend it afterwards so the guard survives; a no-op when the
    # module is still present (e.g. after a path reopen).
    def reopen(*args)
      result = super
      singleton_class.prepend(AngryIO::Guard)
      AngryIO.release!(self) if AngryIO.armed?
      result
    end
  end

  # Kernel#warn writes to stderr at C level without dispatching to
  # $stderr#write (when $stderr is a real IO), so it bypasses Guard. Intercept
  # it at the source. warn always appends a newline per message, so even an
  # empty message emits output; a message-less warn emits nothing.
  module WarnGuard
    def warn(*messages, **options)
      result = super
      AngryIO.check_output!($stderr, messages.map { |m| m.to_s.empty? ? "\n" : m })
      result
    end
  end

  # Warning.warn (deprecations and other Ruby-level warnings) is the same:
  # it writes to stderr without dispatching to $stderr#write.
  module WarningGuard
    def warn(message, **options)
      result = super
      AngryIO.check_output!($stderr, [message])
      result
    end
  end

  # ActiveSupport::Testing::Stream#capture reopens $stdout/$stderr onto a
  # Tempfile and #silence_stream reopens onto IO::NULL — deliberate redirects
  # whose block output is captured or silenced on purpose, not test pollution.
  # Disarm the guard for the duration, the same way Minitest's
  # capture_subprocess_io is handled.
  module ActiveSupportStreamCapture
    def capture(stream)
      AngryIO.disarmed { super }
    end

    def silence_stream(stream)
      AngryIO.disarmed { super }
    end

    private :capture, :silence_stream
  end

  @enabled = -> { true }

  class << self
    attr_accessor :enabled

    # Arm the write-guard on STDOUT/STDERR around the given block, restoring
    # the previous state in an ensure. No-ops when +opted_out+ is true or when
    # +enabled+ returns false, so the block runs untouched.
    def around_streams(opted_out: false)
      return yield if opted_out
      return yield unless enabled.call

      previous_armed = Thread.current.thread_variable_get(:angry_io_armed)
      previous_released = Thread.current.thread_variable_get(:angry_io_released)
      Thread.current.thread_variable_set(:angry_io_armed, true)
      Thread.current.thread_variable_set(:angry_io_released, [])

      begin
        yield
      ensure
        Thread.current.thread_variable_set(:angry_io_armed, previous_armed)
        Thread.current.thread_variable_set(:angry_io_released, previous_released)
      end
    end

    # Run the block with the guard disarmed. Helpers like Minitest's
    # capture_subprocess_io or ActiveSupport's capture need this: they redirect
    # the streams on purpose, so the block's writes are captured, not errors.
    def disarmed
      previous = Thread.current.thread_variable_get(:angry_io_armed)
      Thread.current.thread_variable_set(:angry_io_armed, false)
      yield
    ensure
      Thread.current.thread_variable_set(:angry_io_armed, previous)
    end

    # Whether the write-guard is armed on the current thread. The flag is
    # thread-local (not fiber-local), so captures running inside a Fiber —
    # e.g. Enumerator-based code — see the same state as their test.
    def armed?
      Thread.current.thread_variable_get(:angry_io_armed) || false
    end

    # Release a stream from the guard for the rest of the surrounding test
    # (see Guard#reopen).
    def release!(io)
      released = Thread.current.thread_variable_get(:angry_io_released)
      released << io if released && !released.include?(io)
    end

    # Called by Guard (and the warn intercepts) after a write has gone through
    # to the real stream. Raises IOError if the guard is armed, the target is
    # one of the guarded streams that hasn't been released, and the write would
    # actually emit output (zero-byte writes are allowed). A $stdout/$stderr
    # the user rebound to another object (e.g. capture_io's StringIO) is not
    # guarded, so writes to it are fine.
    # standard:disable Style/GlobalStdStream — we mean the real stream objects, not the globals
    def check_output!(io, strings)
      return unless armed?
      return unless io.equal?(STDOUT) || io.equal?(STDERR)
      return if Thread.current.thread_variable_get(:angry_io_released)&.include?(io)

      offending = strings.map(&:to_s).reject(&:empty?)
      return if offending.empty?

      name = io.equal?(STDOUT) ? "$stdout" : "$stderr"
      # Flush so the offending line really does appear right before the failure
      # even when the stream is block-buffered ($stdout.sync == false, e.g. on
      # CI or under RSpec) — and so the buffer is left empty, keeping a later
      # syswrite from tripping Ruby's "syswrite for buffered IO" warning (which
      # WarningGuard turns into a raise) in an innocent test.
      io.flush
      raise IOError, "AngryIO: a test wrote to #{name}:\n  #{offending.join}"
    end
    # standard:enable Style/GlobalStdStream

    # Prepend hooks so ActiveSupport::Testing::Stream#capture / #silence_stream
    # run with the guard disarmed (see ActiveSupportStreamCapture). No-ops when
    # ActiveSupport isn't loaded.
    def hook_active_support_stream!
      require "active_support/testing/stream"
      ActiveSupport::Testing::Stream.prepend(ActiveSupportStreamCapture)
    rescue LoadError
      # ActiveSupport isn't available; nothing to hook.
    end
  end
end

# standard:disable Style/GlobalStdStream — guard the real stream objects, not the globals
STDOUT.singleton_class.prepend(AngryIO::Guard)
STDERR.singleton_class.prepend(AngryIO::Guard)
# standard:enable Style/GlobalStdStream
Kernel.prepend(AngryIO::WarnGuard)
Kernel.singleton_class.prepend(AngryIO::WarnGuard) # warn is a module_function
Warning.singleton_class.prepend(AngryIO::WarningGuard)
