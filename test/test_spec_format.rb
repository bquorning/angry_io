# frozen_string_literal: true

require "test_helper"

# The adapter is prepended to Minitest::Test and the opt-out class methods are
# extended onto it, so both apply to Minitest::Spec describe blocks as well.
describe "AngryIo in spec format" do
  it "swaps stdout during the example" do
    expect($stdout).must_be_kind_of AngryIo::Stream
  end

  it "swaps stderr during the example" do
    expect($stderr).must_be_kind_of AngryIo::Stream
  end
end

describe "Opting out in spec format" do
  i_absolutely_need_to_write_to_stdout!

  it "does not swap stdout" do
    expect($stdout).wont_be_kind_of AngryIo::Stream
  end

  it "does not swap stderr" do
    expect($stderr).wont_be_kind_of AngryIo::Stream
  end

  describe "a nested describe" do
    it "still swaps stdout, since the opt-out does not propagate downwards" do
      expect($stdout).must_be_kind_of AngryIo::Stream
    end
  end
end

describe "A sibling of an opted-out describe" do
  it "swaps stdout, unaffected by the sibling's opt-out" do
    expect($stdout).must_be_kind_of AngryIo::Stream
  end
end
