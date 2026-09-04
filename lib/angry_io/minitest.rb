# frozen_string_literal: true

require "angry_io"

# Prepends an override of +Minitest::Test#run+ that arms AngryIO's write-guard
# on STDOUT/STDERR around each test. A test class opts out by calling
# +i_absolutely_need_to_write_to_stdout!+ in its body. Force-loads Minitest so
# registration works regardless of Bundler.require ordering.
module AngryIO
  module Minitest
    module Adapter
      def run
        AngryIO.around_streams(opted_out: self.class.i_absolutely_need_to_write_to_stdout?) { super }
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

    def self.setup!
      ::Minitest::Test.extend(ClassMethods)
      ::Minitest::Test.prepend(Adapter)
    end
  end
end

require "minitest"
AngryIO::Minitest.setup!
