# frozen_string_literal: true

require "insta"
require "insta/minitest/assertions"
require "insta/minitest/lifecycle"

module Minitest
  #: (Hash[Symbol, untyped]) -> void
  def self.plugin_insta_init(_options)
    Minitest::Test.include(Insta::Minitest::Assertions)
    Minitest::Test.include(Insta::Minitest::Lifecycle)
  end
end

Minitest.after_run do
  Insta::PendingReporter.flush_and_report!
end
