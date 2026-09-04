# frozen_string_literal: true

# Require this file from your Gemfile (+require: "angry_io/enable_for_ci_true"+)
# to turn AngryIo on only when the +CI+ environment variable is +"true"+ — a
# convention set by GitHub Actions, GitLab CI, CircleCI, Travis, and others.
# Whichever test framework is loaded (RSpec or Minitest) wires itself up; the
# other is a no-op.

require "angry_io"

AngryIo.configure do |config|
  config.enabled = -> { ENV["CI"] == "true" }
end

require "angry_io/rspec"
require "angry_io/minitest"
