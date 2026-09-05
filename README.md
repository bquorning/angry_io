# AngryIo

Friends don't let friends write tests or specs that output to stdout/stderr. When you look at your test output, you should only see green dots, right?

AngryIo replaces `$stdout` and `$stderr` during your test suite with an IO that _raises on write_, so accidental output fails loudly instead of quietly cluttering your output. It ships self-registering adapters for both RSpec and Minitest, gated by a configurable `enabled` callable.

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

By default, AngryIo is always on, and every test that writes to `$stdout` or `$stderr` now raises:

```
IOError: not opened for writing
```

If you want to allow test output in some environments but not in others — e.g., allow output when testing locally, but fail on CI — you can configure like this:

```ruby
# On by default; turn it off in environments where you'll allow real output.
AngryIo.configure do |config|
  config.enabled = -> { ENV["CI"] == "true" }
end
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

`AngryIo.configure` yields a config struct with one field:

| Field              | Default                                 | Description                                                                                                           |
| ---                | ---                                     | ---                                                                                                                   |
| `enabled`          | `-> { true }`                           | A callable returning whether AngryIo is active. Invoked once per test, so it can read env vars or feature flags live. |

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
