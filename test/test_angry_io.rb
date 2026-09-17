# frozen_string_literal: true

require "test_helper"
require "active_support/testing/stream"
require "tmpdir"

class TestAngryIO < Minitest::Test
  def test_stream_raises_on_write
    assert_raises(IOError) { AngryIO::Stream.new.write("x") }
  end

  def test_stream_raises_on_puts
    assert_raises(IOError) { AngryIO::Stream.new.puts("x") }
  end

  def test_stream_raises_on_putc
    assert_raises(IOError) { AngryIO::Stream.new.putc("x") }
  end

  def test_stream_allows_zero_byte_writes
    stream = AngryIO::Stream.new
    stream.write("")
    stream.print("")
    stream.printf("")
    stream << ""
    stream.syswrite("")
    assert_predicate stream.string, :empty?
  end

  def test_enabled_defaults_to_truthy
    assert AngryIO.enabled.call
  end

  def test_around_streams_swaps_and_restores
    original = $stdout
    inside = nil
    AngryIO.around_streams { inside = $stdout }
    assert_kind_of AngryIO::Stream, inside
    assert_equal original, $stdout
  end

  def test_around_streams_noop_when_opted_out
    original = $stdout
    AngryIO.around_streams(opted_out: true) {}
    assert_equal original, $stdout
  end

  def test_around_streams_noop_when_disabled
    AngryIO.enabled = -> { false }
    original = $stdout
    AngryIO.around_streams {}
    assert_equal original, $stdout
  ensure
    AngryIO.enabled = -> { true }
  end

  # The minitest adapter (loaded in test_helper) wraps every test, so $stdout
  # is an AngryIO::Stream for the duration of this example.
  def test_minitest_adapter_swaps_stdout_during_test
    assert_kind_of AngryIO::Stream, $stdout
  end

  def test_with_real_streams_restores_outer_streams
    adapter_stream = $stdout
    AngryIO.around_streams do
      seen = nil
      AngryIO.with_real_streams { seen = $stdout }
      assert_same adapter_stream, seen
      assert_kind_of AngryIO::Stream, $stdout
      refute_same adapter_stream, $stdout
    end
  end

  # The swap is tracked per thread (not per fiber), so captures running inside
  # a Fiber — e.g. Enumerator-based code — still see it.
  def test_with_real_streams_works_across_fibers
    seen = Fiber.new { AngryIO.with_real_streams { $stdout } }.resume
    refute_kind_of AngryIO::Stream, seen
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
    assert_kind_of AngryIO::Stream, $stdout
  end

  # capture_io replaces the globals outright (no reopen), so it already works:
  # writes inside the block land in Minitest's StringIOs, not the Angry stream.
  def test_capture_io_captures_and_restores
    out, err = capture_io do
      $stdout.puts "hello"
      $stderr.puts "warning" # rubocop:disable Style/StderrPuts
    end
    assert_equal "hello\n", out
    assert_equal "warning\n", err
    assert_kind_of AngryIO::Stream, $stdout
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

  # Reopening $stdout onto a real IO (e.g. a socket after a fork) must not raise
  # `TypeError: can't convert IO into StringIO` — it delegates to the original
  # real stream and hands the global back, so writes reach the reopened IO.
  def test_reopen_onto_io_redirects_writes_to_that_io
    real_stdout = $stdout
    read, write = IO.pipe
    original = File.open(File::NULL, "w")
    $stdout = original
    begin
      AngryIO.around_streams do
        assert_kind_of AngryIO::Stream, $stdout
        $stdout.reopen(write)
        refute_kind_of AngryIO::Stream, $stdout
        assert_same original, $stdout
        $stdout.write("redirected\n")
        $stdout.flush
      end
    ensure
      $stdout = real_stdout
      original.close # original was reopened onto write's fd; close that dup -> EOF
    end
    write.close
    captured = read.read
    read.close
    assert_equal "redirected\n", captured
  end

  # Reopening $stderr onto a real IO works the same as $stdout.
  def test_reopen_onto_io_redirects_stderr_to_that_io
    real_stderr = $stderr
    read, write = IO.pipe
    original = File.open(File::NULL, "w")
    $stderr = original
    begin
      AngryIO.around_streams do
        assert_kind_of AngryIO::Stream, $stderr
        $stderr.reopen(write)
        assert_same original, $stderr
      end
    ensure
      $stderr = real_stderr
      original.close
    end
    write.close
    read.close
  end

  # Non-IO args (String/nil) defer to StringIO's own reopen, which resets the
  # buffer — the guard stays in place and writes still raise.
  def test_reopen_onto_string_keeps_the_guard
    AngryIO.around_streams do
      $stdout.reopen("")
      assert_kind_of AngryIO::Stream, $stdout
      assert_raises(IOError) { $stdout.puts "x" }
    end
  end

  # reopen() with no args resets the StringIO buffer via StringIO#reopen(); the
  # guard stays in place, so writes still raise.
  def test_reopen_with_no_args_resets_buffer_and_keeps_guard
    AngryIO.around_streams do
      $stdout.reopen
      assert_kind_of AngryIO::Stream, $stdout
      assert_raises(IOError) { $stdout.puts "x" }
    end
  end

  # With no active swap there's no original to delegate to, so an IO arg falls
  # back to StringIO's behavior (raising TypeError), matching a plain StringIO.
  def test_reopen_onto_io_without_swap_raises_like_stringio
    stream = AngryIO::Stream.new
    read, write = IO.pipe
    prev = Thread.current.thread_variable_get(:angry_io_swap)
    Thread.current.thread_variable_set(:angry_io_swap, nil)
    begin
      assert_raises(TypeError) { stream.reopen(write) }
    ensure
      Thread.current.thread_variable_set(:angry_io_swap, prev)
      read.close
      write.close
    end
  end

  # A swap is active, but `self` is a standalone AngryIO::Stream that wasn't one
  # of the swapped buffers (someone assigned it to $stdout outside the adapter).
  # There's no original for it to delegate to, so it falls back to StringIO and
  # raises TypeError instead of silently no-op'ing.
  def test_reopen_onto_io_with_swap_but_unmatched_stream_raises
    read, write = IO.pipe
    standalone = AngryIO::Stream.new
    AngryIO.around_streams do
      assert_raises(TypeError) { standalone.reopen(write) }
    end
  ensure
    read.close
    write.close
  end
end

# A class that opts out by declaring it needs stdout, proving the mechanism.
class TestAngryIOOptOut < Minitest::Test
  i_absolutely_need_to_write_to_stdout!

  def test_does_not_swap_stdout_when_opted_out
    refute_kind_of AngryIO::Stream, $stdout
  end

  # This class opts out of around_streams, so no swap is active during the
  # test — with_real_streams must be a no-op that yields without touching the
  # globals.
  def test_with_real_streams_noop_when_no_swap
    original = $stdout
    AngryIO.with_real_streams { assert_equal original, $stdout }
    assert_equal original, $stdout
  end

  # With no swap active, real_stream_for has nothing to map to and returns nil.
  def test_real_stream_for_returns_nil_without_swap
    assert_nil AngryIO.real_stream_for($stdout)
    assert_nil AngryIO.real_stream_for($stderr)
  end
end

# Exercises the ActiveSupport::Testing::Stream hook. Its `capture` reopens
# $stdout/$stderr onto Tempfiles — only possible on real IOs — so the prepended
# wrapper (installed by hook_active_support_stream! at adapter load) restores
# the real streams for the duration, then hands the Angry buffer back. Without
# the hook these would raise TypeError on the StringIO.
class TestAngryIOActiveSupport < Minitest::Test
  include ActiveSupport::Testing::Stream

  def test_capture_stdout_catches_ruby_and_subprocess_writes
    assert_kind_of AngryIO::Stream, $stdout
    out = capture(:stdout) do
      $stdout.puts "ruby-write"
      system("echo subprocess-write")
    end
    assert_equal "ruby-write\nsubprocess-write\n", out
    assert_kind_of AngryIO::Stream, $stdout
  end

  def test_capture_stderr_catches_ruby_and_subprocess_writes
    assert_kind_of AngryIO::Stream, $stderr
    err = capture(:stderr) do
      warn "ruby-err"
      system("echo subprocess-err >&2")
    end
    assert_equal "ruby-err\nsubprocess-err\n", err
    assert_kind_of AngryIO::Stream, $stderr
  end

  # `quietly` chains silence_stream over the STDOUT/STDERR constants (real IOs);
  # the wrapper swaps $stdout/$stderr to them, silence_stream redirects each to
  # IO::NULL, so the block's writes are silenced. The nested silence_stream
  # calls also exercise with_real_streams' reentrancy guard. If the swap broke,
  # the block's writes would raise against the Angry buffer instead.
  def test_quietly_silences_writes_and_restores
    quietly do
      $stdout.puts "hushed"
      warn "hushed-err"
    end
    assert_kind_of AngryIO::Stream, $stdout
    assert_kind_of AngryIO::Stream, $stderr
  end

  # `silence_stream($stdout)` is called with the AngryIO buffer (bound at call
  # time). The wrapper must substitute the real stream so AS reopens *it* onto
  # IO::NULL — otherwise the block's writes leak to the real stdout. Use a plain
  # File as the real stdout (via a nested around_streams) so a leak shows up as
  # non-empty file contents. (A Tempfile won't do: its EXCL mode makes
  # reopen(IO::NULL) raise EEXIST.)
  def test_silence_stream_silences_writes_under_angry_io
    real_stdout = $stdout
    Dir.mktmpdir do |dir|
      probe = File.open(File.join(dir, "probe.log"), "w+")
      $stdout = probe
      begin
        AngryIO.around_streams do
          assert_kind_of AngryIO::Stream, $stdout
          silence_stream($stdout) { $stdout.puts "hushed" }
          assert_kind_of AngryIO::Stream, $stdout
        end
        probe.rewind
        assert_equal "", probe.read
      ensure
        $stdout = real_stdout
        probe.close
      end
    end
  end

  # Same as above for $stderr: silence_stream($stderr) must substitute the real
  # stderr so `warn`/`$stderr` writes are silenced, not leaked.
  def test_silence_stream_silences_stderr_writes_under_angry_io
    real_stderr = $stderr
    Dir.mktmpdir do |dir|
      probe = File.open(File.join(dir, "probe.err"), "w+")
      $stderr = probe
      begin
        AngryIO.around_streams do
          assert_kind_of AngryIO::Stream, $stderr
          silence_stream($stderr) { warn "hushed-err" }
          assert_kind_of AngryIO::Stream, $stderr
        end
        probe.rewind
        assert_equal "", probe.read
      ensure
        $stderr = real_stderr
        probe.close
      end
    end
  end
end
