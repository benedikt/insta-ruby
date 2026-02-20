# frozen_string_literal: true

require_relative "../test_helper"

class SnapshotTest < Minitest::Spec
  test "parse plain content" do
    snapshot = Insta::Snapshot.parse("hello world\n")

    assert_equal "hello world\n", snapshot.content
    assert_equal({}, snapshot.metadata)
  end

  test "parse with frontmatter" do
    raw = <<~SNAP
      ---
      source: "MyTest#test_output"
      input: "<div>hello</div>"
      ---
      expected output
    SNAP

    snapshot = Insta::Snapshot.parse(raw)

    assert_equal "expected output\n", snapshot.content
    assert_equal "MyTest#test_output", snapshot.source
    assert_equal "<div>hello</div>", snapshot.input
  end

  test "parse with multiline input" do
    raw = <<~SNAP
      ---
      source: "MyTest#test_output"
      input: |
        <div>
          hello
        </div>
      ---
      expected output
    SNAP

    snapshot = Insta::Snapshot.parse(raw)

    assert_equal "expected output\n", snapshot.content
    assert_equal "<div>\n  hello\n</div>\n", snapshot.input
  end

  test "parse with description" do
    raw = <<~SNAP
      ---
      source: "Test#method"
      description: "A test description"
      ---
      content here
    SNAP

    snapshot = Insta::Snapshot.parse(raw)

    assert_equal "A test description", snapshot.description
  end

  test "serialize without metadata" do
    snapshot = Insta::Snapshot.new("hello world\n")

    assert_equal "hello world\n", snapshot.serialize
  end

  test "serialize with metadata" do
    metadata = { "source" => "MyTest#test_output" }
    snapshot = Insta::Snapshot.new("content\n", metadata)
    serialized = snapshot.serialize

    assert_includes serialized, "---\n"
    assert_includes serialized, "MyTest#test_output"
    assert_includes serialized, "content\n"
  end

  test "roundtrip with source and description" do
    metadata = { "source" => "MyTest#test_output", "description" => "A test" }
    original = Insta::Snapshot.new("hello world\n", metadata)
    parsed = Insta::Snapshot.parse(original.serialize)

    assert_equal original.content, parsed.content
    assert_equal original.source, parsed.source
    assert_equal original.description, parsed.description
  end

  test "roundtrip with multiline input" do
    metadata = { "source" => "Test#method", "input" => "<div>\n  hello\n</div>\n" }
    original = Insta::Snapshot.new("output\n", metadata)
    parsed = Insta::Snapshot.parse(original.serialize)

    assert_equal original.content, parsed.content
    assert_equal original.source, parsed.source
    assert_equal original.input, parsed.input
  end

  test "roundtrip with options" do
    metadata = { "source" => "Test#method", "options" => { track_whitespace: true } }
    original = Insta::Snapshot.new("output\n", metadata)
    parsed = Insta::Snapshot.parse(original.serialize)

    assert_equal original.content, parsed.content
    assert_equal original.metadata["options"], parsed.metadata["options"]
  end

  test "roundtrip with info" do
    metadata = { "source" => "Test#method", "info" => { "key" => "value", "nested" => { "a" => 1 } } }
    original = Insta::Snapshot.new("output\n", metadata)
    parsed = Insta::Snapshot.parse(original.serialize)

    assert_equal original.content, parsed.content
    assert_equal original.info, parsed.info
  end

  test "empty content" do
    snapshot = Insta::Snapshot.parse("")

    assert_equal "", snapshot.content
  end

  test "info metadata" do
    raw = <<~SNAP
      ---
      source: "Test#method"
      info:
        key: value
      ---
      content
    SNAP

    snapshot = Insta::Snapshot.parse(raw)

    assert_equal({ "key" => "value" }, snapshot.info)
  end
end
