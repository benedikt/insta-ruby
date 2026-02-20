# frozen_string_literal: true

require_relative "../../test_helper"
require "prism"

class CallFinderTest < Minitest::Spec
  test "finds assert_inline_snapshot call" do
    source = <<~RUBY
      def test_example
        assert_inline_snapshot("hello", <<~SNAP)
          expected
        SNAP
      end
    RUBY

    result = Prism.parse(source)
    finder = Insta::Inline::CallFinder.new(2)
    finder.visit(result.value)

    assert_instance_of Prism::CallNode, finder.found_call
    assert_equal :assert_inline_snapshot, finder.found_call.name
  end

  test "finds match_inline_snapshot call" do
    source = <<~RUBY
      it "works" do
        expect(result).to match_inline_snapshot(<<~SNAP)
          expected
        SNAP
      end
    RUBY

    result = Prism.parse(source)
    finder = Insta::Inline::CallFinder.new(2)
    finder.visit(result.value)

    assert_instance_of Prism::CallNode, finder.found_call
    assert_equal :match_inline_snapshot, finder.found_call.name
  end

  test "does not find unrelated calls" do
    source = <<~RUBY
      def test_example
        assert_equal "hello", "world"
      end
    RUBY

    result = Prism.parse(source)
    finder = Insta::Inline::CallFinder.new(2)
    finder.visit(result.value)

    assert_nil finder.found_call
  end

  test "finds call on correct line" do
    source = <<~RUBY
      def test_first
        assert_inline_snapshot("a", "expected_a")
      end

      def test_second
        assert_inline_snapshot("b", "expected_b")
      end
    RUBY

    result = Prism.parse(source)

    finder1 = Insta::Inline::CallFinder.new(2)
    finder1.visit(result.value)
    assert_instance_of Prism::CallNode, finder1.found_call

    finder2 = Insta::Inline::CallFinder.new(6)
    finder2.visit(result.value)
    assert_instance_of Prism::CallNode, finder2.found_call
  end

  test "finds no-arg call" do
    source = <<~RUBY
      def test_example
        assert_inline_snapshot("hello")
      end
    RUBY

    result = Prism.parse(source)
    finder = Insta::Inline::CallFinder.new(2)
    finder.visit(result.value)

    assert_instance_of Prism::CallNode, finder.found_call
  end
end
