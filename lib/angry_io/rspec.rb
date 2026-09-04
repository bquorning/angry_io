# frozen_string_literal: true

require "angry_io"

# Registers an +around+ hook that swaps $stdout/$stderr to AngryIo::Stream
# instances during each example, unless the example opts out via the configured
# metadata (default +:i_absolutely_need_to_write_to_stdout+). Force-loads
# rspec-core so registration works regardless of Bundler.require ordering;
# no-op if RSpec isn't installed.
module AngryIo
  module RSpec
    def self.setup!
      ::RSpec.configure do |config|
        config.around do |example|
          opt_out = example.metadata.key?(AngryIo.config.opt_out_metadata) &&
            example.metadata[AngryIo.config.opt_out_metadata]
          AngryIo.around_streams(opted_out: opt_out) { example.run }
        end
      end
    end
  end
end

begin
  require "rspec/core"
  AngryIo::RSpec.setup!
rescue LoadError
  # RSpec isn't installed; nothing to wire up.
end
