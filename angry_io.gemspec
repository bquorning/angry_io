# frozen_string_literal: true

require_relative "lib/angry_io/version"

Gem::Specification.new do |spec|
  spec.name = "angry_io"
  spec.version = AngryIO::VERSION
  spec.authors = ["Benjamin Quorning"]
  spec.email = ["bquorning@zendesk.com"]

  spec.summary = "Guards stdout/stderr during tests: writes go through, then raise."
  spec.description = "AngryIO guards the real $stdout/$stderr during tests: a write goes through to the stream and then raises, so accidental output fails loudly and the offending line is visible in the test output. Ships RSpec and Minitest adapters that self-register, gated by a configurable enabled callable."
  spec.homepage = "https://github.com/bquorning/angry_io"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"
  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = %w[
    CHANGELOG.md
    LICENSE.txt
    README.md
    lib/angry_io.rb
    lib/angry_io/minitest.rb
    lib/angry_io/rspec.rb
    lib/angry_io/version.rb
  ]
  spec.require_paths = ["lib"]
end
