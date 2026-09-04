# frozen_string_literal: true

require "angry_io"

# Registers an +around+ hook that arms AngryIO's write-guard on STDOUT/STDERR
# during each example, unless the example opts out via the
# +:i_absolutely_need_to_write_to_stdout+ metadata. Force-loads rspec-core so
# registration works regardless of Bundler.require ordering.
module AngryIO
  module RSpec
    def self.setup!
      ::RSpec.configure do |config|
        config.around do |example|
          opt_out = example.metadata.key?(:i_absolutely_need_to_write_to_stdout) &&
            example.metadata[:i_absolutely_need_to_write_to_stdout]
          AngryIO.around_streams(opted_out: opt_out) { example.run }
        end
      end
    end
  end
end

require "rspec/core"
AngryIO::RSpec.setup!
