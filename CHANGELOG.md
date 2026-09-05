## [Unreleased]

- AngryIO guards the real `STDOUT`/`STDERR` objects during tests — a write goes through to the stream and then raises `IOError`, so accidental output fails loudly and the offending line is visible in the test output right before the failure. Because the guard lives on the stream objects themselves, code holding earlier references (e.g. `Logger.new($stdout)` at boot) cannot bypass it; `Kernel#warn` and `Warning.warn` are intercepted at the source, since they write to stderr without dispatching to `$stderr#write`.
- Self-registering adapters for Minitest and RSpec arm the guard around each test, with an opt-out per test class / example via `i_absolutely_need_to_write_to_stdout`.
- `AngryIO.enabled` is a callable gating enforcement (default `-> { true }`), invoked once per test — e.g. `-> { ENV["CI"] == "true" }` to enforce on CI while leaving local debuggers usable.
- Known limits: the arming flag is thread-local, so writes from threads spawned mid-test are not guarded, and rebinding `$stdout` to another IO bypasses the guard.
- Zero-byte writes (e.g. `$stderr.print("")`) emit nothing and are allowed; anything that would produce output raises. `warn("")` still raises: `warn` appends a newline per message, so an empty message is not a zero-byte write.
