# AngryIo

Friends don't let friends write tests or specs that outputs to stdout/stderr. When you look at your test output, you should only see green dots, right?

AngryIo replaces `$stdout` and `$stderr` during your test suite with an IO that _raises on write_, so accidental output fails loudly instead of quietly cluttering your output. It ships self-registering adapters for both RSpec and Minitest, gated by a configurable `enabled` callable.

The name and the default opt-out metadata are a nod to [minitest](https://github.com/minitest/minitest)'s `i_suck_and_my_tests_are_order_dependent!`.

## Installation

Add to your application's Gemfile:

```ruby
group :test do
  gem "angry_io", require: "angry_io/enable_for_ci_true"
end
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install angry_io
```

## Usage

The simplest setup is to point the Gemfile `require:` at `angry_io/enable_for_ci_true`. That file turns AngryIo on only when the `CI` environment variable is `"true"` — a convention set by GitHub Actions, GitLab CI, CircleCI, Travis, and others — and wires up whichever test framework is loaded (RSpec or Minitest); the other is a no-op.

```ruby
# Gemfile
gem "angry_io", require: "angry_io/enable_for_ci_true"
```

That's it. Under `CI=true`, every test that writes to `$stdout` or `$stderr` raises:

```
IOError: not opened for writing
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

### Manual setup

If you'd rather control the gate yourself, require an adapter directly. `enabled` defaults to always-on, so it's most useful as a kill switch for environments where you need real output:

```ruby
# spec_helper.rb (RSpec) or test_helper.rb (Minitest)
require "angry_io/rspec"      # or "angry_io/minitest"

# On by default; turn it off in environments where you need real output.
AngryIo.configure do |config|
  config.enabled = -> { ENV["ANGRY_IO"] != "off" }
end
```

Requiring `angry_io/rspec` or `angry_io/minitest` self-registers the hook if that framework is loaded; requiring plain `angry_io` gives you just the `AngryIo::Stream` class with no side effects.

## Configuration

`AngryIo.configure` yields a config struct with two fields:

| Field              | Default                                 | Description                                                                                                           |
| ---                | ---                                     | ---                                                                                                                   |
| `enabled`          | `-> { true }`                           | A callable returning whether AngryIo is active. Invoked once per test, so it can read env vars or feature flags live. |
| `opt_out_metadata` | `:i_absolutely_need_to_write_to_stdout` | The RSpec metadata symbol that opts an example out.                                                                   |

## How it works

`AngryIo::Stream` is a `StringIO` backed by a frozen empty string, which makes `StringIO` refuse writes with an `IOError`. Around each test, the adapter swaps `$stdout` and `$stderr` to fresh `AngryIo::Stream` instances and restores the originals (closing the buffers) in an `ensure`.

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

Everyone interacting in the AngryIo project's codebases, issue trackers, chat rooms, and mailing lists is expected to follow the [code of conduct](https://github.com/bquorning/angry_io/blob/main/CODE_OF_CONDUCT.md).
