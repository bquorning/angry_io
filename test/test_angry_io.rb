# frozen_string_literal: true

require "test_helper"

class TestAngryIo < Minitest::Test
  def test_stream_raises_on_write
    assert_raises(IOError) { AngryIo::Stream.new.write("x") }
  end

  def test_stream_raises_on_puts
    assert_raises(IOError) { AngryIo::Stream.new.puts("x") }
  end

  def test_stream_raises_on_putc
    assert_raises(IOError) { AngryIo::Stream.new.putc("x") }
  end

  def test_stream_allows_zero_byte_writes
    stream = AngryIo::Stream.new
    stream.write("")
    stream.print("")
    stream.printf("")
    stream << ""
    stream.syswrite("")
    assert_predicate stream.string, :empty?
  end

  def test_config_defaults
    config = AngryIo::Config.new
    assert config.enabled.call
  end

  def test_around_streams_swaps_and_restores
    original = $stdout
    inside = nil
    AngryIo.around_streams { inside = $stdout }
    assert_kind_of AngryIo::Stream, inside
    assert_equal original, $stdout
  end

  def test_around_streams_noop_when_opted_out
    original = $stdout
    AngryIo.around_streams(opted_out: true) {}
    assert_equal original, $stdout
  end

  def test_around_streams_noop_when_disabled
    AngryIo.configure { |c| c.enabled = -> { false } }
    original = $stdout
    AngryIo.around_streams {}
    assert_equal original, $stdout
  ensure
    AngryIo.configure { |c| c.enabled = -> { true } }
  end

  # The minitest adapter (loaded in test_helper) wraps every test, so $stdout
  # is an AngryIo::Stream for the duration of this example.
  def test_minitest_adapter_swaps_stdout_during_test
    assert_kind_of AngryIo::Stream, $stdout
  end

  def test_with_real_streams_restores_outer_streams
    adapter_stream = $stdout
    AngryIo.around_streams do
      seen = nil
      AngryIo.with_real_streams { seen = $stdout }
      assert_same adapter_stream, seen
      assert_kind_of AngryIo::Stream, $stdout
      refute_same adapter_stream, $stdout
    end
  end

  # The swap is tracked per thread (not per fiber), so captures running inside
  # a Fiber — e.g. Enumerator-based code — still see it.
  def test_with_real_streams_works_across_fibers
    seen = Fiber.new { AngryIo.with_real_streams { $stdout } }.resume
    refute_kind_of AngryIo::Stream, seen
  end

  def test_capture_subprocess_io_works_inside_a_fiber
    out = Fiber.new { capture_subprocess_io { system("echo hello") }.first }.resume
    assert_equal "hello\n", out
  end

  def test_capture_subprocess_io_captures_and_restores
    out, err = capture_subprocess_io do
      system("echo hello")
      warn "warning"
    end
    assert_equal "hello\n", out
    assert_equal "warning\n", err
    assert_kind_of AngryIo::Stream, $stdout
  end

  # capture_io replaces the globals outright (no reopen), so it already works:
  # writes inside the block land in Minitest's StringIOs, not the Angry stream.
  def test_capture_io_captures_and_restores
    out, err = capture_io do
      $stdout.puts "hello"
      $stderr.puts "warning"
    end
    assert_equal "hello\n", out
    assert_equal "warning\n", err
    assert_kind_of AngryIo::Stream, $stdout
  end

  def test_assert_output
    assert_output("hello\n", "warning\n") do
      $stdout.puts "hello"
      $stderr.puts "warning"
    end
  end

  def test_assert_silent
    assert_silent { nil }
  end
end

# A class that opts out by declaring it needs stdout, proving the mechanism.
class TestAngryIoOptOut < Minitest::Test
  i_absolutely_need_to_write_to_stdout!

  def test_does_not_swap_stdout_when_opted_out
    refute_kind_of AngryIo::Stream, $stdout
  end
end
