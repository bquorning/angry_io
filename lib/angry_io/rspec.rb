# frozen_string_literal: true

require "angry_io"

# Registers an +around+ hook that swaps $stdout/$stderr to AngryIo::Stream
# instances during each example, unless the example opts out via the
# +:i_absolutely_need_to_write_to_stdout+ metadata. Force-loads rspec-core so
# registration works regardless of Bundler.require ordering.
module AngryIo
  module RSpec
    # The to_*_from_any_process matchers reopen $stdout/$stderr onto Tempfiles
    # so subprocesses inherit the file descriptors, which fails on
    # StringIO-based streams. An example using these matchers captures output
    # on purpose, so restore the real streams while the matcher grabs the
    # stream...
    module FromAnyProcess
      def to_stdout_from_any_process
        AngryIo.with_real_streams { super }
      end

      def to_stderr_from_any_process
        AngryIo.with_real_streams { super }
      end
    end

    # ...and while the block runs, so Ruby-level writes inside the expect block
    # are captured by the Tempfile instead of raising against the Angry stream.
    module CaptureStreamToTempfile
      def capture(block)
        AngryIo.with_real_streams { super }
      end
    end

    def self.setup!
      ::RSpec.configure do |config|
        config.around do |example|
          opt_out = example.metadata.key?(:i_absolutely_need_to_write_to_stdout) &&
            example.metadata[:i_absolutely_need_to_write_to_stdout]
          AngryIo.around_streams(opted_out: opt_out) { example.run }
        end
      end

      ::RSpec::Matchers::BuiltIn::Output.prepend(FromAnyProcess)
      ::RSpec::Matchers::BuiltIn::CaptureStreamToTempfile.prepend(CaptureStreamToTempfile)
    end
  end
end

require "rspec/core"
require "rspec/expectations"
AngryIo::RSpec.setup!
