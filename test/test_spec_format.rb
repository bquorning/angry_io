# frozen_string_literal: true

require "test_helper"

# The adapter is prepended to Minitest::Test and the opt-out class methods are
# extended onto it, so both apply to Minitest::Spec describe blocks as well.
describe "AngryIO in spec format" do
  it "arms the guard during the example" do
    expect(AngryIO.armed?).must_equal true
  end

  it "supports must_output expectations" do
    _ { $stdout.puts "hello" }.must_output "hello\n"
    expect(AngryIO.armed?).must_equal true
  end
end

describe "Opting out in spec format" do
  i_absolutely_need_to_write_to_stdout!

  it "does not arm the guard" do
    expect(AngryIO.armed?).must_equal false
  end

  describe "a nested describe" do
    it "arms the guard, since the opt-out does not propagate downwards" do
      expect(AngryIO.armed?).must_equal true
    end
  end
end

describe "A sibling of an opted-out describe" do
  it "arms the guard, unaffected by the sibling's opt-out" do
    expect(AngryIO.armed?).must_equal true
  end
end
