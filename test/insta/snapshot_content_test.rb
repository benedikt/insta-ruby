# frozen_string_literal: true

require_relative "../test_helper"

class SnapshotContentTest < Minitest::Spec
  test "normalize adds trailing newline" do
    assert_equal "hello\n", Insta::SnapshotContent.normalize("hello")
  end

  test "normalize preserves single trailing newline" do
    assert_equal "hello\n", Insta::SnapshotContent.normalize("hello\n")
  end

  test "normalize removes extra trailing newlines" do
    assert_equal "hello\n", Insta::SnapshotContent.normalize("hello\n\n")
  end

  test "normalize converts CRLF" do
    assert_equal "hello\nworld\n", Insta::SnapshotContent.normalize("hello\r\nworld\r\n")
  end

  test "normalize converts CR" do
    assert_equal "hello\nworld\n", Insta::SnapshotContent.normalize("hello\rworld\r")
  end

  test "indent" do
    result = Insta::SnapshotContent.indent("hello\nworld\n", 4)

    assert_equal "    hello\n    world\n", result
  end

  test "indent preserves empty lines" do
    result = Insta::SnapshotContent.indent("hello\n\nworld\n", 2)

    assert_equal "  hello\n\n  world\n", result
  end

  test "strip indent" do
    input = "    hello\n    world"
    result = Insta::SnapshotContent.strip_indent(input)

    assert_equal "hello\nworld", result
  end

  test "strip indent mixed" do
    input = "    hello\n      world"
    result = Insta::SnapshotContent.strip_indent(input)

    assert_equal "hello\n  world", result
  end

  test "strip indent empty string" do
    assert_equal "", Insta::SnapshotContent.strip_indent("")
  end
end
