# frozen_string_literal: true

require_relative "lib/angry_io/version"

Gem::Specification.new do |spec|
  spec.name = "angry_io"
  spec.version = AngryIo::VERSION
  spec.authors = ["Benjamin Quorning"]
  spec.email = ["bquorning@zendesk.com"]

  spec.summary = "An IO that raises on write, to keep tests from polluting stdout/stderr."
  spec.description = "AngryIo replaces $stdout/$stderr during tests with an IO that raises on write, so accidental output fails loudly instead of cluttering CI logs. Ships RSpec and Minitest adapters that self-register, gated by a configurable enabled callable."
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
