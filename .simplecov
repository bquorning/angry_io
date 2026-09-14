# frozen_string_literal: true

# Auto-loaded by SimpleCov before every `SimpleCov.start`. The framework
# helpers (test/test_helper.rb, spec/spec_helper.rb) keep only their distinct
# `command_name` so the two runs merge into a single report.
SimpleCov.configure do
  enable_coverage :branch
  skip "/test/"
  skip "/spec/"
end
