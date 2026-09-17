## [Unreleased]

## [0.5.0] - 2026-09-17

- Replace `AngryIO.configure` / `AngryIO::Config` with a direct `AngryIO.enabled` accessor (still a callable, default `-> { true }`). This is a breaking change: replace `AngryIO.configure { |c| c.enabled = ... }` with `AngryIO.enabled = ...`.
- Rename the core module from `AngryIo` to `AngryIO` (`AngryIO::Stream`, `AngryIO.enabled`, `AngryIO.with_real_streams`, etc.). This is a breaking change: no backwards-compatibility alias is provided, so any code referencing the old `AngryIo` constant must be updated. The lowercase gem name (`angry_io`) and require paths (`angry_io/rspec`, `angry_io/minitest`) are unchanged.

## [0.4.0] - 2026-09-15

- Reopening `$stdout`/`$stderr` onto a real IO (e.g. `$stdout.reopen(File::NULL)`) no longer raises `TypeError` under `AngryIo::Stream`. `Stream#reopen` now delegates an IO argument to the original real stream it replaced (a `dup2` that survives the caller closing the other IO) and hands the global back so writes reach the reopened IO; non-IO arguments still defer to StringIO's own buffer reset. The new `AngryIo.real_stream_for` returns the real stream a swapped buffer replaced.
- ActiveSupport's `capture` and `silence_stream` (from `ActiveSupport::Testing::Stream`) now work alongside AngryIo. They use the same reopen-onto-IO pattern as `capture_subprocess_io`, so AngryIo now runs them under `with_real_streams`, substituting the real stream for the StringIO buffer that `silence_stream` binds at call time.
- `AngryIo.with_real_streams` is now reentrant: a nested call (e.g. ActiveSupport's `capture` wrapping `quietly`, whose nested `silence_stream` re-enters the helper) no longer swaps the globals back to the Angry buffers while the outer call still expects the real streams. It no-ops when the real streams are already current.

## [0.3.0] - 2026-09-06

- Zero-byte writes (e.g. `$stderr.print("")`) no longer raise; `AngryIo::Stream` now raises only when a write would actually emit output. The error message changed from StringIO's `not opened for writing` to `AngryIo::Stream is not writable: ...`, which includes the offending output.
- Minitest's `capture_subprocess_io` and RSpec's `to_stdout_from_any_process` / `to_stderr_from_any_process` matchers now work alongside AngryIo. These helpers reopen `$stdout`/`$stderr` onto Tempfiles so subprocesses inherit the file descriptors, which fails on the StringIO-based `AngryIo::Stream`; AngryIo now restores the real streams for their duration via a new `AngryIo.with_real_streams` helper.

## [0.2.0] - 2026-09-04

- Remove the `angry_io/enable_for_ci_true` convenience require; require `angry_io/rspec` or `angry_io/minitest` directly instead.
- Remove the configurable `opt_out_metadata` field; the RSpec opt-out metadata is now always `:i_absolutely_need_to_write_to_stdout`.
- Adapters no longer swallow `LoadError` when their framework is missing; requiring an adapter now hard-requires its framework.

## [0.1.0] - 2026-09-04

- Initial release
