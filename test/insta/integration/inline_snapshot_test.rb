# frozen_string_literal: true

require_relative "../../test_helper"
require "tmpdir"
require "fileutils"

class InlineSnapshotIntegrationTest < Minitest::Spec
  def setup
    super
    @tmpdir = Dir.mktmpdir
    Insta.configure do |config|
      config.update_mode = :force
    end
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
    super
  end

  test "pending registry collects entries" do
    Insta::Inline::PendingRegistry.clear!
    Insta::Inline::PendingRegistry.add(
      file: "test.rb",
      line: 5,
      content: "hello\n",
      type: :replace
    )

    assert Insta::Inline::PendingRegistry.any?
    assert_equal 1, Insta::Inline::PendingRegistry.size
  end

  test "pending registry clear" do
    Insta::Inline::PendingRegistry.add(
      file: "test.rb",
      line: 1,
      content: "x\n",
      type: :replace
    )
    Insta::Inline::PendingRegistry.clear!

    refute Insta::Inline::PendingRegistry.any?
    assert_equal 0, Insta::Inline::PendingRegistry.size
  end

  test "file patcher with string replacement" do
    source = <<~RUBY
      assert_inline_snapshot("actual_value", "old_expected")
    RUBY

    file = File.join(@tmpdir, "test_inline.rb")
    File.write(file, source)

    result = Insta::Inline::FilePatcher.patch(file, [
                                                { line: 1, content: "new_expected\n", type: :replace }
                                              ])

    assert_includes result, '"new_expected"'
    refute_includes result, '"old_expected"'
  end

  test "file patcher with heredoc replacement converts single-line to string literal" do
    source = <<~RUBY
      assert_inline_snapshot("actual", <<~SNAP)
        old content here
      SNAP
    RUBY

    file = File.join(@tmpdir, "test_heredoc.rb")
    File.write(file, source)

    result = Insta::Inline::FilePatcher.patch(file, [
                                                { line: 1, content: "new content here\n", type: :replace }
                                              ])

    assert_includes result, "new content here"
    refute_includes result, "old content here"
    refute_includes result, "SNAP"
    assert_includes result, '"new content here"'
  end

  test "file patcher multiple edits in same file" do
    source = <<~RUBY
      assert_inline_snapshot("a", "old_a")
      assert_inline_snapshot("b", "old_b")
    RUBY

    file = File.join(@tmpdir, "test_multi.rb")
    File.write(file, source)

    result = Insta::Inline::FilePatcher.patch(file, [
                                                { line: 1, content: "new_a\n", type: :replace },
                                                { line: 2, content: "new_b\n", type: :replace }
                                              ])

    assert_includes result, '"new_a"'
    assert_includes result, '"new_b"'
    refute_includes result, '"old_a"'
    refute_includes result, '"old_b"'
  end

  test "file patcher preserves surrounding code" do
    source = <<~RUBY
      # Header comment
      def test_example
        value = compute_something
        assert_inline_snapshot(value, "old")
        do_other_things
      end
      # Footer comment
    RUBY

    file = File.join(@tmpdir, "test_preserve.rb")
    File.write(file, source)

    result = Insta::Inline::FilePatcher.patch(file, [
                                                { line: 4, content: "new\n", type: :replace }
                                              ])

    assert_includes result, "# Header comment"
    assert_includes result, "# Footer comment"
    assert_includes result, "compute_something"
    assert_includes result, "do_other_things"
    assert_includes result, '"new"'
  end

  test "atomic write" do
    file = File.join(@tmpdir, "atomic_test.rb")
    Insta::Inline::FilePatcher.send(:atomic_write, file, "hello world")

    assert_equal "hello world", File.read(file)
  end
end
