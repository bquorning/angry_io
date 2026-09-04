# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  command_name "Minitest"
end

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "minitest/spec"
require "minitest/rg"
require "angry_io/minitest"
