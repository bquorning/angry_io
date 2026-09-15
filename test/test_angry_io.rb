# frozen_string_literal: true

require "test_helper"
require "active_support/testing/stream"
require "logger"
require "tmpdir"

# Created at load time, before any test runs — the reported bypass: a logger
# holding a reference to the real $stdout must still be guarded.
BOOT_LOGGER = Logger.new($stdout)

class TestAngryIO < Minitest::Test
  def test_enabled_defaults_to_truthy
    assert AngryIO.enabled.call
  end

  # The minitest adapter (loaded in test_helper) wraps every test, so the
  # guard is armed for the duration of this test.
  def test_minitest_adapter_arms_the_guard_during_a_test
    assert AngryIO.armed?
  end

  def test_around_streams_arms_and_restores
    AngryIO.disarmed do
      refute AngryIO.armed?
      AngryIO.around_streams { assert AngryIO.armed? }
      refute AngryIO.armed?
    end
  end

  def test_around_streams_noop_when_opted_out
    AngryIO.disarmed do
      AngryIO.around_streams(opted_out: true) { refute AngryIO.armed? }
    end
  end

  def test_around_streams_noop_when_disabled
    AngryIO.enabled = -> { false }
    AngryIO.disarmed do
      AngryIO.around_streams { refute AngryIO.armed? }
    end
  ensure
    AngryIO.enabled = -> { true }
  end

  # Each of these writes goes through to the real stdout/stderr and then
  # raises, so this test's output shows the offending lines — that's the
  # debugging aid, dogfooded.
  def test_all_write_methods_raise
    assert_raises(IOError) { $stdout.write("x") }
    assert_raises(IOError) { $stdout.puts "x" }
    assert_raises(IOError) { $stdout.print "x" }
    assert_raises(IOError) { $stdout.printf "%s", "x" }
    assert_raises(IOError) { $stdout << "x" }
    assert_raises(IOError) { $stdout.syswrite "x" }
    assert_raises(IOError) { $stdout.write_nonblock "x" }
    assert_raises(IOError) { $stdout.putc "x" }
    assert_raises(IOError) { $stderr.write "x" }
    assert_raises(IOError) { warn "x" }
  end

  def test_error_message_names_the_stream_and_shows_the_output
    error = assert_raises(IOError) { $stdout.write("bang") }
    assert_match(/\$stdout/, error.message)
    assert_match(/bang/, error.message)

    error = assert_raises(IOError) { $stderr.write("boom") }
    assert_match(/\$stderr/, error.message)
    assert_match(/boom/, error.message)
  end

  def test_zero_byte_writes_are_allowed
    $stdout.write("")
    $stdout.print("")
    $stdout.printf("")
    $stdout << ""
    $stdout.syswrite("")
    $stderr.print("")
  end

  # A logger created before the test started holds a reference to the real
  # STDOUT object. Because the guard lives on that object (not on the $stdout
  # global), logger writes are caught too.
  def test_logger_holding_the_stream_from_boot_still_raises
    error = assert_raises(IOError) { BOOT_LOGGER.info("sneaky") }
    assert_match(/sneaky/, error.message)
    assert_raises(IOError) { BOOT_LOGGER << "sneaky\n" }
  end

  def test_disarmed_allows_output_for_the_block
    AngryIO.disarmed do
      refute AngryIO.armed?
      $stdout.write("")
    end
    assert AngryIO.armed?
  end

  # A nested disarmed block must not re-arm the guard for the outer block.
  def test_disarmed_is_reentrant
    AngryIO.disarmed do
      AngryIO.disarmed { refute AngryIO.armed? }
      refute AngryIO.armed?
    end
    assert AngryIO.armed?
  end

  # The arming flag is tracked per thread (not per fiber), so code running
  # inside a Fiber — e.g. Enumerator-based code — sees the same state.
  def test_guard_state_works_across_fibers
    assert Fiber.new { AngryIO.armed? }.resume
    refute Fiber.new { AngryIO.disarmed { AngryIO.armed? } }.resume
  end

  def test_capture_subprocess_io_works_inside_a_fiber
    out = Fiber.new { capture_subprocess_io { system("echo hello") }.first }.resume
    assert_equal "hello\n", out
  end

  def test_capture_subprocess_io_captures_and_restores
    out, err = capture_subprocess_io do
      refute AngryIO.armed?
      system("echo hello")
      warn "warning"
    end
    assert_equal "hello\n", out
    assert_equal "warning\n", err
    assert AngryIO.armed?
  end

  # capture_io replaces the globals outright (no reopen), so it already works:
  # writes inside the block land in Minitest's unguarded StringIOs.
  def test_capture_io_captures_and_restores
    out, err = capture_io do
      $stdout.puts "hello"
      $stderr.puts "warning" # rubocop:disable Style/StderrPuts
    end
    assert_equal "hello\n", out
    assert_equal "warning\n", err
    assert AngryIO.armed?
  end

  def test_assert_output
    assert_output("hello\n", "warning\n") do
      $stdout.puts "hello"
      $stderr.puts "warning" # rubocop:disable Style/StderrPuts
    end
  end

  def test_assert_silent
    assert_silent { nil }
  end

  # Reopening $stdout onto a real IO (e.g. a socket after a fork) deliberately
  # redirects the process's output, so the guard releases the stream: writes
  # reach the reopened target instead of raising.
  def test_reopen_onto_io_redirects_writes_to_that_io
    read, write = IO.pipe
    saved = $stdout.dup
    begin
      $stdout.reopen(write)
      $stdout.write("redirected\n")
      $stdout.flush
    ensure
      $stdout.reopen(saved)
      saved.close
      write.close
    end
    captured = read.read
    read.close
    assert_equal "redirected\n", captured
  end

  # Reopening $stderr onto a real IO works the same as $stdout.
  def test_reopen_onto_io_redirects_stderr_to_that_io
    saved = $stderr.dup
    begin
      $stderr.reopen(File::NULL)
      warn "hushed"
    ensure
      $stderr.reopen(saved)
      saved.close
    end
    assert AngryIO.armed?
  end

  # A failed reopen must not release the guard — the redirect never happened.
  # (A closed IO is used to fail the reopen: a failed *path* reopen goes through
  # freopen(3), which closes the original fd — we don't want to destroy the
  # test process's real stdout.)
  def test_failed_reopen_keeps_the_guard
    read, write = IO.pipe
    write.close
    assert_raises(IOError) { $stdout.reopen(write) }
    assert_raises(IOError) { $stdout.write("still guarded") }
  ensure
    read.close
  end
end

# A class that opts out by declaring it needs stdout, proving the mechanism.
class TestAngryIOOptOut < Minitest::Test
  i_absolutely_need_to_write_to_stdout!

  def test_guard_is_not_armed_when_opted_out
    refute AngryIO.armed?
  end
end

# Exercises the ActiveSupport::Testing::Stream hook. Its `capture` and
# `silence_stream` reopen $stdout/$stderr onto a Tempfile / IO::NULL — which
# works natively now that $stdout is the real stream — so the prepended
# wrapper (installed by hook_active_support_stream! at adapter load) only
# needs to disarm the guard for the duration.
class TestAngryIOActiveSupport < Minitest::Test
  include ActiveSupport::Testing::Stream

  def test_capture_stdout_catches_ruby_and_subprocess_writes
    assert AngryIO.armed?
    out = capture(:stdout) do
      refute AngryIO.armed?
      $stdout.puts "ruby-write"
      system("echo subprocess-write")
    end
    assert_equal "ruby-write\nsubprocess-write\n", out
    assert AngryIO.armed?
  end

  def test_capture_stderr_catches_ruby_and_subprocess_writes
    assert AngryIO.armed?
    err = capture(:stderr) do
      refute AngryIO.armed?
      warn "ruby-err"
      system("echo subprocess-err >&2")
    end
    assert_equal "ruby-err\nsubprocess-err\n", err
    assert AngryIO.armed?
  end

  # `quietly` chains silence_stream over the STDOUT/STDERR constants. The
  # nested silence_stream calls also exercise the disarmed wrapper's
  # reentrancy. If the guard weren't disarmed, the block's writes would raise.
  def test_quietly_silences_writes_and_restores
    quietly do
      $stdout.puts "hushed"
      warn "hushed-err"
    end
    assert AngryIO.armed?
  end

  # silence_stream($stdout) receives the real STDOUT and reopens it onto
  # IO::NULL itself — no substitution needed. The block's writes are silenced,
  # and the guard is still armed (and functional) afterwards.
  def test_silence_stream_silences_writes_and_keeps_the_guard
    silence_stream($stdout) { $stdout.puts "hushed" }
    silence_stream($stderr) { warn "hushed-err" }
    assert AngryIO.armed?
    assert_raises(IOError) { $stdout.write("still guarded") }
  end
end
