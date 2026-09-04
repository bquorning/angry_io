# frozen_string_literal: true

require "test_helper"
require "logger"

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
    states = Thread.new {
      inside = nil
      AngryIO.around_streams { inside = AngryIO.armed? }
      [inside, AngryIO.armed?]
    }.value
    assert_equal [true, false], states
  end

  def test_around_streams_noop_when_opted_out
    refute Thread.new { AngryIO.around_streams(opted_out: true) { AngryIO.armed? } }.value
  end

  def test_around_streams_noop_when_disabled
    AngryIO.enabled = -> { false }
    refute Thread.new { AngryIO.around_streams { AngryIO.armed? } }.value
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

  # A logger created before the test started holds a reference to the real
  # STDOUT object. Because the guard lives on that object (not on the $stdout
  # global), logger writes are caught too.
  def test_logger_holding_the_stream_from_boot_still_raises
    error = assert_raises(IOError) { BOOT_LOGGER.info("sneaky") }
    assert_match(/sneaky/, error.message)
    assert_raises(IOError) { BOOT_LOGGER << "sneaky\n" }
  end

  # The arming flag is tracked per thread (not per fiber), so code running
  # inside a Fiber — e.g. Enumerator-based code — sees the same state.
  def test_guard_state_works_across_fibers
    assert Fiber.new { AngryIO.armed? }.resume
  end
end

# A class that opts out by declaring it needs stdout, proving the mechanism.
class TestAngryIOOptOut < Minitest::Test
  i_absolutely_need_to_write_to_stdout!

  def test_guard_is_not_armed_when_opted_out
    refute AngryIO.armed?
  end
end
