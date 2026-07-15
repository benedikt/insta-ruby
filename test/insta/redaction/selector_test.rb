# frozen_string_literal: true

require_relative "../../test_helper"

class SelectorTest < Minitest::Spec
  test "parses simple key .id" do
    selector = Insta::Redaction::Selector.new(".id")
    assert_equal 1, selector.segments.length
    assert_equal :key, selector.segments[0].type
    assert_equal "id", selector.segments[0].value
  end

  test "parses nested key .user.name" do
    selector = Insta::Redaction::Selector.new(".user.name")
    assert_equal 2, selector.segments.length
    assert_equal :key, selector.segments[0].type
    assert_equal "user", selector.segments[0].value
    assert_equal :key, selector.segments[1].type
    assert_equal "name", selector.segments[1].value
  end

  test "parses array index [0]" do
    selector = Insta::Redaction::Selector.new("[0]")
    assert_equal 1, selector.segments.length
    assert_equal :index, selector.segments[0].type
    assert_equal 0, selector.segments[0].value
  end

  test "parses full range []" do
    selector = Insta::Redaction::Selector.new("[]")
    assert_equal 1, selector.segments.length
    assert_equal :full_range, selector.segments[0].type
  end

  test "parses wildcard .*" do
    selector = Insta::Redaction::Selector.new(".*")
    assert_equal 1, selector.segments.length
    assert_equal :wildcard, selector.segments[0].type
  end

  test "parses deep wildcard .**" do
    selector = Insta::Redaction::Selector.new(".**")
    assert_equal 1, selector.segments.length
    assert_equal :deep_wildcard, selector.segments[0].type
  end

  test "parses compound .items[].id" do
    selector = Insta::Redaction::Selector.new(".items[].id")
    assert_equal 3, selector.segments.length
    assert_equal :key, selector.segments[0].type
    assert_equal "items", selector.segments[0].value
    assert_equal :full_range, selector.segments[1].type
    assert_equal :key, selector.segments[2].type
    assert_equal "id", selector.segments[2].value
  end

  test "parses quoted key [\"special-key\"]" do
    selector = Insta::Redaction::Selector.new("[\"special-key\"]")
    assert_equal 1, selector.segments.length
    assert_equal :key, selector.segments[0].type
    assert_equal "special-key", selector.segments[0].value
  end

  test "parses deep wildcard with suffix .**.id" do
    selector = Insta::Redaction::Selector.new(".**.id")
    assert_equal 2, selector.segments.length
    assert_equal :deep_wildcard, selector.segments[0].type
    assert_equal :key, selector.segments[1].type
    assert_equal "id", selector.segments[1].value
  end

  test "raises on empty string" do
    assert_raises(ArgumentError) { Insta::Redaction::Selector.new("") }
  end

  test "raises on missing dot prefix" do
    assert_raises(ArgumentError) { Insta::Redaction::Selector.new("id") }
  end

  test "raises on double deep wildcard" do
    assert_raises(ArgumentError) { Insta::Redaction::Selector.new(".**.**") }
  end

  test "matches simple key path" do
    selector = Insta::Redaction::Selector.new(".id")
    assert selector.matches?([{ type: :key, value: "id" }])
    refute selector.matches?([{ type: :key, value: "name" }])
  end

  test "matches nested key path" do
    selector = Insta::Redaction::Selector.new(".user.name")
    assert selector.matches?([{ type: :key, value: "user" }, { type: :key, value: "name" }])
    refute selector.matches?([{ type: :key, value: "user" }])
    refute selector.matches?([{ type: :key, value: "user" }, { type: :key, value: "id" }])
  end

  test "matches array index path" do
    selector = Insta::Redaction::Selector.new("[0]")
    assert selector.matches?([{ type: :index, value: 0 }])
    refute selector.matches?([{ type: :index, value: 1 }])
  end

  test "matches full range" do
    selector = Insta::Redaction::Selector.new(".items[]")
    assert selector.matches?([{ type: :key, value: "items" }, { type: :index, value: 0 }])
    assert selector.matches?([{ type: :key, value: "items" }, { type: :index, value: 5 }])
    refute selector.matches?([{ type: :key, value: "other" }, { type: :index, value: 0 }])
  end

  test "matches wildcard" do
    selector = Insta::Redaction::Selector.new(".*")
    assert selector.matches?([{ type: :key, value: "anything" }])
    refute selector.matches?([{ type: :index, value: 0 }])
  end

  test "matches deep wildcard" do
    selector = Insta::Redaction::Selector.new(".**")
    assert selector.matches?([{ type: :key, value: "a" }])
    assert selector.matches?([{ type: :key, value: "a" }, { type: :key, value: "b" }])
    assert selector.matches?([{ type: :index, value: 0 }])
  end

  test "matches deep wildcard with suffix .**.id" do
    selector = Insta::Redaction::Selector.new(".**.id")
    assert selector.matches?([{ type: :key, value: "id" }])
    assert selector.matches?([{ type: :key, value: "user" }, { type: :key, value: "id" }])
    assert selector.matches?([{ type: :key, value: "a" }, { type: :key, value: "b" }, { type: :key, value: "id" }])
    refute selector.matches?([{ type: :key, value: "name" }])
    refute selector.matches?([{ type: :key, value: "id" }, { type: :key, value: "name" }])
  end

  test "matches compound .items[].id" do
    selector = Insta::Redaction::Selector.new(".items[].id")
    assert selector.matches?([
                               { type: :key, value: "items" },
                               { type: :index, value: 0 },
                               { type: :key, value: "id" }
                             ])
    assert selector.matches?([
                               { type: :key, value: "items" },
                               { type: :index, value: 3 },
                               { type: :key, value: "id" }
                             ])
    refute selector.matches?([
                               { type: :key, value: "items" },
                               { type: :index, value: 0 },
                               { type: :key, value: "name" }
                             ])
  end

  test "matches symbol keys via to_s" do
    selector = Insta::Redaction::Selector.new(".id")
    assert selector.matches?([{ type: :key, value: :id }])
  end
end
