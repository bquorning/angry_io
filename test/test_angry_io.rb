# frozen_string_literal: true

require "test_helper"

class TestAngryIo < Minitest::Test
  def test_stream_raises_on_write
    assert_raises(IOError) { AngryIo::Stream.new.write("x") }
  end

  def test_stream_raises_on_puts
    assert_raises(IOError) { AngryIo::Stream.new.puts("x") }
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
end

# A class that opts out by declaring it needs stdout, proving the mechanism.
class TestAngryIoOptOut < Minitest::Test
  i_absolutely_need_to_write_to_stdout!

  def test_does_not_swap_stdout_when_opted_out
    refute_kind_of AngryIo::Stream, $stdout
  end
end
