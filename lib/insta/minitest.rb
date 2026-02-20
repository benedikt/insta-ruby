# frozen_string_literal: true

require "minitest"
require "insta"
require "minitest/insta_plugin"

Minitest::Test.include(Insta::Minitest::Assertions)
Minitest::Test.include(Insta::Minitest::Lifecycle)
