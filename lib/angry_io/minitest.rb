# frozen_string_literal: true

require "angry_io"

# Prepends an override of +Minitest::Test#run+ that swaps $stdout/$stderr to
# AngryIo::Stream instances around each test. A test class opts out by calling
# +i_absolutely_need_to_write_to_stdout!+ in its body — a nod to minitest's own
# +i_suck_and_my_tests_are_order_dependent!+. Force-loads Minitest so
# registration works regardless of Bundler.require ordering; no-op if Minitest
# isn't installed.
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

    def self.setup!
      test = ::Minitest::Test
      test.extend(ClassMethods)
      test.prepend(Adapter)
    end
  end
end

begin
  require "minitest"
  AngryIo::Minitest.setup!
rescue LoadError
  # Minitest isn't installed; nothing to wire up.
end
