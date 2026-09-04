## [Unreleased]

## [0.2.0] - 2026-09-04

- Remove the `angry_io/enable_for_ci_true` convenience require; require `angry_io/rspec` or `angry_io/minitest` directly instead.
- Remove the configurable `opt_out_metadata` field; the RSpec opt-out metadata is now always `:i_absolutely_need_to_write_to_stdout`.
- Adapters no longer swallow `LoadError` when their framework is missing; requiring an adapter now hard-requires its framework.

## [0.1.0] - 2026-09-04

- Initial release
