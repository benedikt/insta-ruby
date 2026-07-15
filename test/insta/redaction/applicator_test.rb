# frozen_string_literal: true

require_relative "../../test_helper"

class ApplicatorTest < Minitest::Spec
  test "returns value unchanged when redactions are nil" do
    data = { "id" => 1 }
    result = Insta::Redaction::Applicator.apply(data, nil)
    assert_equal({ "id" => 1 }, result)
  end

  test "returns value unchanged when redactions are empty" do
    data = { "id" => 1 }
    result = Insta::Redaction::Applicator.apply(data, {})
    assert_equal({ "id" => 1 }, result)
  end

  test "raises ArgumentError for non-Hash/Array" do
    assert_raises(ArgumentError) do
      Insta::Redaction::Applicator.apply("string", { ".id" => "[redacted]" })
    end
  end

  test "raises ArgumentError for integer" do
    assert_raises(ArgumentError) do
      Insta::Redaction::Applicator.apply(42, { ".id" => "[redacted]" })
    end
  end

  test "simple key redaction" do
    data = { "id" => "abc-123", "name" => "Alice" }
    result = Insta::Redaction::Applicator.apply(data, { ".id" => "[uuid]" })
    assert_equal({ "id" => "[uuid]", "name" => "Alice" }, result)
  end

  test "nested key redaction" do
    data = { "user" => { "name" => "Alice", "id" => "xyz" } }
    result = Insta::Redaction::Applicator.apply(data, { ".user.id" => "[uuid]" })
    assert_equal({ "user" => { "name" => "Alice", "id" => "[uuid]" } }, result)
  end

  test "array index redaction" do
    data = ["a", "b", "c"]
    result = Insta::Redaction::Applicator.apply(data, { "[1]" => "[redacted]" })
    assert_equal(["a", "[redacted]", "c"], result)
  end

  test "all array items redaction" do
    data = { "items" => [{ "id" => "a" }, { "id" => "b" }] }
    result = Insta::Redaction::Applicator.apply(data, { ".items[].id" => "[uuid]" })
    assert_equal({ "items" => [{ "id" => "[uuid]" }, { "id" => "[uuid]" }] }, result)
  end

  test "wildcard redaction" do
    data = { "a" => 1, "b" => 2, "c" => 3 }
    result = Insta::Redaction::Applicator.apply(data, { ".*" => "[redacted]" })
    assert_equal({ "a" => "[redacted]", "b" => "[redacted]", "c" => "[redacted]" }, result)
  end

  test "deep wildcard redaction .**.id" do
    data = {
      "id" => "top",
      "nested" => {
        "id" => "mid",
        "deep" => { "id" => "bottom", "name" => "keep" },
      },
    }
    result = Insta::Redaction::Applicator.apply(data, { ".**.id" => "[uuid]" })
    assert_equal({
      "id" => "[uuid]",
      "nested" => {
        "id" => "[uuid]",
        "deep" => { "id" => "[uuid]", "name" => "keep" },
      },
    }, result)
  end

  test "multiple redactions" do
    data = { "id" => "abc", "created_at" => "2024-01-01", "name" => "Alice" }
    result = Insta::Redaction::Applicator.apply(data, {
      ".id" => "[uuid]",
      ".created_at" => "[timestamp]",
    })
    assert_equal({ "id" => "[uuid]", "created_at" => "[timestamp]", "name" => "Alice" }, result)
  end

  test "proc replacement" do
    data = { "score" => 3.14159 }
    result = Insta::Redaction::Applicator.apply(data, {
      ".score" => ->(v) { v.round(2) },
    })
    assert_equal({ "score" => 3.14 }, result)
  end

  test "sorted replacement" do
    data = { "tags" => ["charlie", "alice", "bob"] }
    result = Insta::Redaction::Applicator.apply(data, { ".tags" => :sorted })
    assert_equal({ "tags" => ["alice", "bob", "charlie"] }, result)
  end

  test "sorted on non-array returns unchanged" do
    data = { "name" => "Alice" }
    result = Insta::Redaction::Applicator.apply(data, { ".name" => :sorted })
    assert_equal({ "name" => "Alice" }, result)
  end

  test "does not mutate original" do
    data = { "id" => "abc-123", "name" => "Alice" }
    original_id = data["id"]
    Insta::Redaction::Applicator.apply(data, { ".id" => "[uuid]" })
    assert_equal original_id, data["id"]
  end

  test "symbol keys match selectors" do
    data = { id: "abc-123", name: "Alice" }
    result = Insta::Redaction::Applicator.apply(data, { ".id" => "[uuid]" })
    assert_equal({ id: "[uuid]", name: "Alice" }, result)
  end

  test "nil value gets replaced" do
    data = { "id" => nil }
    result = Insta::Redaction::Applicator.apply(data, { ".id" => "[uuid]" })
    assert_equal({ "id" => "[uuid]" }, result)
  end

  test "empty hash returns empty hash" do
    result = Insta::Redaction::Applicator.apply({}, { ".id" => "[uuid]" })
    assert_equal({}, result)
  end

  test "empty array returns empty array" do
    result = Insta::Redaction::Applicator.apply([], { "[0]" => "[redacted]" })
    assert_equal([], result)
  end

  test "first matching selector wins" do
    data = { "id" => "abc" }
    result = Insta::Redaction::Applicator.apply(data, {
      ".id" => "[first]",
      ".*" => "[second]",
    })
    assert_equal({ "id" => "[first]" }, result)
  end

  test "deep wildcard only covers nested" do
    data = { "a" => { "b" => 1 }, "c" => 2 }
    result = Insta::Redaction::Applicator.apply(data, { ".**" => "[redacted]" })
    assert_equal({ "a" => "[redacted]", "c" => "[redacted]" }, result)
  end

  test "quoted key redaction" do
    data = { "special-key" => "value" }
    result = Insta::Redaction::Applicator.apply(data, { "[\"special-key\"]" => "[redacted]" })
    assert_equal({ "special-key" => "[redacted]" }, result)
  end
end
