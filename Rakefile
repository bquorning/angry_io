# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:spec)

require "standard/rake"

task default: %i[test spec standard]
