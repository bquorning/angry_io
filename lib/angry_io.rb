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
    def syswrite(string)
      result = super
      AngryIO.check_output!(self, [string])
      result
    end

    def write_nonblock(string, **options)
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
      Thread.current.thread_variable_set(:angry_io_armed, true)

      begin
        yield
      ensure
        Thread.current.thread_variable_set(:angry_io_armed, previous_armed)
      end
    end

    # Whether the write-guard is armed on the current thread. The flag is
    # thread-local (not fiber-local), so captures running inside a Fiber —
    # e.g. Enumerator-based code — see the same state as their test.
    def armed?
      Thread.current.thread_variable_get(:angry_io_armed) || false
    end

    # Called by Guard (and the warn intercepts) after a write has gone through
    # to the real stream. Raises IOError if the guard is armed, the target is
    # one of the guarded streams, and the write would actually emit output
    # (zero-byte writes are allowed). A $stdout/$stderr the user rebound to
    # another object (e.g. capture_io's StringIO) is not guarded, so writes to
    # it are fine.
    # standard:disable Style/GlobalStdStream — we mean the real stream objects, not the globals
    def check_output!(io, strings)
      return unless armed?
      return unless io.equal?(STDOUT) || io.equal?(STDERR)

      offending = strings.map(&:to_s).reject(&:empty?)
      return if offending.empty?

      name = io.equal?(STDOUT) ? "$stdout" : "$stderr"
      raise IOError, "AngryIO: a test wrote to #{name}: #{offending.join.inspect}"
    end
    # standard:enable Style/GlobalStdStream
  end
end

# standard:disable Style/GlobalStdStream — guard the real stream objects, not the globals
STDOUT.singleton_class.prepend(AngryIO::Guard)
STDERR.singleton_class.prepend(AngryIO::Guard)
# standard:enable Style/GlobalStdStream
Kernel.prepend(AngryIO::WarnGuard)
Kernel.singleton_class.prepend(AngryIO::WarnGuard) # warn is a module_function
Warning.singleton_class.prepend(AngryIO::WarningGuard)
