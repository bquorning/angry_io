# AngryIO

Friends don't let friends write tests or specs that output to stdout/stderr. When you look at your test output, you should only see green dots, right?

AngryIO guards the real `$stdout` and `$stderr` during your test suite: a write goes through to the stream and then immediately _raises_, so accidental output fails loudly instead of quietly cluttering your output — and the offending line is right there in your test output, next to the failure, making it easy to find what printed. Because the guard lives on the stream objects themselves (not on the globals), code that captured a reference earlier — e.g. `Logger.new($stdout)` at boot — can't bypass it. AngryIO ships self-registering adapters for both RSpec and Minitest, gated by a configurable `enabled` callable.

## Installation

Add to your application's Gemfile:

```ruby
group :test do
  gem "angry_io"
end
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install angry_io
```

## Usage

Depending on your test framework, you should require either `angry_io/rspec` or `angry_io/minitest`:

```ruby
# spec_helper.rb (RSpec) or test_helper.rb (Minitest)
require "angry_io/rspec"      # or "angry_io/minitest"
```

By default, AngryIO is always on, and every test that writes to `$stdout` or `$stderr` now prints the offending output and then raises:

```
your output here
IOError: AngryIO: a test wrote to $stdout: "your output here"
```

Zero-byte writes (e.g. `$stderr.print("")`) emit nothing, so they are allowed.

If you want to allow test output in some environments but not in others — e.g., fail on CI, but allow output when testing locally so REPL debuggers like `binding.irb` or `pry` work — set the `enabled` predicate:

```ruby
# On by default; turn it off in environments where you'll allow real output
# (e.g. locally, so a debugger can write to stdout without raising).
AngryIO.enabled = -> { ENV["CI"] == "true" }
```

### Opting out

While onboarding this gem, some tests will likely already be writing to stdout. Opt them out per-test until they are fixed:

```ruby
# RSpec
it "prints a deprecation", :i_absolutely_need_to_write_to_stdout do
  puts "deprecated!"
end
```

```ruby
# Minitest — opt out a whole test class
class PrintTest < Minitest::Test
  i_absolutely_need_to_write_to_stdout!

  def test_prints
    puts "ok"
  end
end
```

The same call works in Minitest's spec format, inside the `describe` block:

```ruby
# Minitest spec format — opt out a whole describe block
describe "printing" do
  i_absolutely_need_to_write_to_stdout!

  it "prints" do
    puts "ok"
  end
end
```

## Configuration

`AngryIO.enabled` is a callable returning whether AngryIO is active. It defaults to `-> { true }` and is invoked once per test, so it can read env vars or feature flags live — e.g. `-> { ENV["CI"] == "true" }` to enforce on CI while leaving local debuggers usable.

## How it works

At load time, AngryIO prepends a small guard module onto the `STDOUT` and `STDERR` objects, overriding their write methods. Around each test, the adapter arms the guard via a thread-local flag, and disarms it in an `ensure`. When armed, a write passes through to the real stream and then raises an `IOError`; zero-byte writes (e.g. `$stderr.print("")`) emit nothing and are allowed.

Guarding the stream objects — rather than swapping the `$stdout`/`$stderr` globals — means anything holding a reference to the real streams (like a `Logger.new($stdout)` from boot time) is guarded too. `Kernel#warn` and `Warning.warn` write to stderr at C level without dispatching to `$stderr#write`, so AngryIO intercepts them at the source as well. Helpers that capture output on purpose keep working: `capture_io` rebinds the globals to unguarded `StringIO`s, and the adapters disarm the guard around `capture_subprocess_io` and RSpec's `to_*_from_any_process` matchers, which reopen the streams onto Tempfiles so subprocesses inherit the file descriptors.

Two limits to be aware of: the arming flag is thread-local, so writes from threads spawned mid-test are not guarded; and rebinding `$stdout` to another IO bypasses the guard (we can't guard an object we've never seen).

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake` to run the test suite (Minitest + RSpec, both dogfooding the gem's own adapters) and StandardRB.

To install this gem onto your local machine, run `bundle exec rake install`.

### Releasing

Releases are automated. Bump the version in `lib/angry_io/version.rb`, commit, and merge to `main` — the `Publish to RubyGems.org` workflow builds the gem, creates and pushes the `vX.Y.Z` tag, and pushes the `.gem` file to [rubygems.org](https://rubygems.org) via trusted publishing (OIDC, no stored API key). You can also trigger a release manually from the Actions tab via `workflow_dispatch`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/bquorning/angry_io.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the AngryIO project's codebases, issue trackers, chat rooms, and mailing lists is expected to follow the [code of conduct](https://github.com/bquorning/angry_io/blob/main/CODE_OF_CONDUCT.md).
