## [Unreleased]

## [0.3.0] - 2026-09-06

- Zero-byte writes (e.g. `$stderr.print("")`) no longer raise; `AngryIo::Stream` now raises only when a write would actually emit output. The error message changed from StringIO's `not opened for writing` to `AngryIo::Stream is not writable: ...`, which includes the offending output.
- Minitest's `capture_subprocess_io` and RSpec's `to_stdout_from_any_process` / `to_stderr_from_any_process` matchers now work alongside AngryIo. These helpers reopen `$stdout`/`$stderr` onto Tempfiles so subprocesses inherit the file descriptors, which fails on the StringIO-based `AngryIo::Stream`; AngryIo now restores the real streams for their duration via a new `AngryIo.with_real_streams` helper.

## [0.2.0] - 2026-09-04

- Remove the `angry_io/enable_for_ci_true` convenience require; require `angry_io/rspec` or `angry_io/minitest` directly instead.
- Remove the configurable `opt_out_metadata` field; the RSpec opt-out metadata is now always `:i_absolutely_need_to_write_to_stdout`.
- Adapters no longer swallow `LoadError` when their framework is missing; requiring an adapter now hard-requires its framework.

## [0.1.0] - 2026-09-04

- Initial release
