# frozen_string_literal: true

require_relative "../../test_helper"

class FilePatcherTest < Minitest::Spec
  test "apply edits single edit" do
    source = "hello world"
    edits = [Insta::Inline::Edit.new(6, 11, "ruby")]
    result = Insta::Inline::FilePatcher.apply_edits(source, edits)

    assert_equal "hello ruby", result
  end

  test "apply edits multiple non-overlapping" do
    source = "aaa bbb ccc"
    edits = [
      Insta::Inline::Edit.new(0, 3, "xxx"),
      Insta::Inline::Edit.new(8, 11, "zzz")
    ]
    result = Insta::Inline::FilePatcher.apply_edits(source, edits)

    assert_equal "xxx bbb zzz", result
  end

  test "apply edits descending order" do
    source = "ab"
    edits = [
      Insta::Inline::Edit.new(0, 1, "x"),
      Insta::Inline::Edit.new(1, 2, "y")
    ]
    result = Insta::Inline::FilePatcher.apply_edits(source, edits)

    assert_equal "xy", result
  end

  test "patch replaces string literal" do
    source = <<~RUBY
      assert_inline_snapshot("actual", "old expected")
    RUBY

    with_patched_file(source, line: 1, content: "new expected\n") do |result|
      assert_equal <<~RUBY, result
        assert_inline_snapshot("actual", "new expected")
      RUBY
    end
  end

  test "patch replaces heredoc with single-line content using string literal" do
    source = <<~RUBY
      assert_inline_snapshot("actual", <<~SNAP)
        old content
      SNAP
    RUBY

    with_patched_file(source, line: 1, content: "new content\n") do |result|
      assert_equal <<~RUBY, result
        assert_inline_snapshot("actual", "new content")
      RUBY
    end
  end

  test "insert single-line content uses string literal" do
    source = <<~RUBY
      assert_inline_snapshot(result)
    RUBY

    with_patched_file(source, line: 1, content: "Hello, world!\n", type: :insert) do |result|
      assert_equal <<~RUBY, result
        assert_inline_snapshot(result, "Hello, world!")
      RUBY
    end
  end

  test "insert single-line content with existing args uses string literal" do
    source = <<~RUBY
      assert_inline_snapshot("actual")
    RUBY

    with_patched_file(source, line: 1, content: "expected value\n", type: :insert) do |result|
      assert_equal <<~RUBY, result
        assert_inline_snapshot("actual", "expected value")
      RUBY
    end
  end

  test "insert multi-line content uses heredoc" do
    source = <<~RUBY
      assert_inline_snapshot(result)
    RUBY

    with_patched_file(source, line: 1, content: "line one\nline two\n", type: :insert) do |result|
      assert_equal <<~RUBY, result
        assert_inline_snapshot(result, <<~SNAP)
          line one
          line two
        SNAP
      RUBY
    end
  end

  test "insert multi-line content with existing args uses heredoc" do
    source = <<~RUBY
      assert_inline_snapshot("actual")
    RUBY

    with_patched_file(source, line: 1, content: "line one\nline two\n", type: :insert) do |result|
      assert_equal <<~RUBY, result
        assert_inline_snapshot("actual", <<~SNAP)
          line one
          line two
        SNAP
      RUBY
    end
  end

  test "replace single-line string staying single-line" do
    source = <<~RUBY
      assert_inline_snapshot("actual", "old value")
    RUBY

    with_patched_file(source, line: 1, content: "new value\n") do |result|
      assert_equal <<~RUBY, result
        assert_inline_snapshot("actual", "new value")
      RUBY
    end
  end

  test "replace heredoc staying multi-line" do
    source = <<~RUBY
      assert_inline_snapshot("actual", <<~SNAP)
        old line one
        old line two
      SNAP
    RUBY

    with_patched_file(source, line: 1, content: "new line one\nnew line two\n") do |result|
      assert_equal <<~RUBY, result
        assert_inline_snapshot("actual", <<~SNAP)
          new line one
          new line two
        SNAP
      RUBY
    end
  end

  test "replace single-line string with multi-line content" do
    source = <<~RUBY
      assert_inline_snapshot("actual", "old value")
    RUBY

    with_patched_file(source, line: 1, content: "line one\nline two\n") do |result|
      assert_equal <<~RUBY, result
        assert_inline_snapshot("actual", <<~SNAP)
          line one
          line two
        SNAP
      RUBY
    end
  end

  test "replace heredoc with single-line content" do
    source = <<~RUBY
      assert_inline_snapshot("actual", <<~SNAP)
        old line one
        old line two
      SNAP
    RUBY

    with_patched_file(source, line: 1, content: "single line\n") do |result|
      assert_equal <<~RUBY, result
        assert_inline_snapshot("actual", "single line")
      RUBY
    end
  end

  test "patch preserves surrounding code" do
    source = <<~RUBY
      # before
      assert_inline_snapshot("actual", "old")
      # after
    RUBY

    with_patched_file(source, line: 2, content: "new\n") do |result|
      assert_equal <<~RUBY, result
        # before
        assert_inline_snapshot("actual", "new")
        # after
      RUBY
    end
  end

  private

  def with_patched_file(source, line:, content:, type: :replace)
    Dir.mktmpdir do |dir|
      file = File.join(dir, "test_example.rb")
      File.write(file, source)

      result = Insta::Inline::FilePatcher.patch(file, [{ line: line, content: content, type: type }])
      yield result
    end
  end
end
