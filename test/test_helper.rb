# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "insta/minitest"
require "maxitest/autorun"
require "minitest/spec"

Minitest::Spec::DSL.send(:alias_method, :test, :it)
Minitest::Spec::DSL.send(:alias_method, :xtest, :xit)

module InstaTestHelper
  def setup
    super

    Insta.reset_configuration!
    Insta::Inline::PendingRegistry.clear!
    Insta::PendingLocations.clear!
  end
end

Minitest::Spec.prepend(InstaTestHelper)
