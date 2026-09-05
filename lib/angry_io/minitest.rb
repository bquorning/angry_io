# frozen_string_literal: true

require "angry_io"

# Prepends an override of +Minitest::Test#run+ that swaps $stdout/$stderr to
# AngryIo::Stream instances around each test. A test class opts out by calling
# +i_absolutely_need_to_write_to_stdout!+ in its body. Force-loads Minitest so
# registration works regardless of Bundler.require ordering.
module AngryIo
  module Minitest
    module Adapter
      def run
        AngryIo.around_streams(opted_out: self.class.i_absolutely_need_to_write_to_stdout?) { super }
      end
    end

    module ClassMethods
      def i_absolutely_need_to_write_to_stdout!
        @i_absolutely_need_to_write_to_stdout = true
      end

      def i_absolutely_need_to_write_to_stdout?
        @i_absolutely_need_to_write_to_stdout ||= false
      end
    end

    # capture_subprocess_io reopens $stdout/$stderr onto Tempfiles so
    # subprocesses inherit the file descriptors, which fails on StringIO-based
    # streams. A test calling it captures output on purpose, so restore the
    # real streams for the duration of the capture.
    module CaptureSubprocessIo
      def capture_subprocess_io(&block)
        AngryIo.with_real_streams { super }
      end
    end

    def self.setup!
      ::Minitest::Test.extend(ClassMethods)
      ::Minitest::Test.prepend(Adapter)
      ::Minitest::Assertions.prepend(CaptureSubprocessIo)
    end
  end
end

require "minitest"
AngryIo::Minitest.setup!
