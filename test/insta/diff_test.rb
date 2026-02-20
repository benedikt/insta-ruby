# frozen_string_literal: true

require_relative "../test_helper"

class DiffTest < Minitest::Spec
  test "terminal width returns integer" do
    width = Insta::Diff.terminal_width

    assert_kind_of Integer, width
    assert_operator width, :>, 0
  end

  test "failure message includes test name" do
    message = Insta::Diff.failure_message("expected\n", "actual\n", "MyTest#test_output")

    assert_includes message, "MyTest#test_output"
  end

  test "failure message includes snapshot path" do
    message = Insta::Diff.failure_message("expected\n", "actual\n", "test", "test/snapshots/foo.snap")

    assert_includes message, "test/snapshots/foo.snap"
  end

  test "failure message includes update hint" do
    message = Insta::Diff.failure_message("expected\n", "actual\n", "test", nil, "test/foo_test.rb:10:in 'test_bar'")

    assert_includes message, "INSTA_UPDATE=force"
  end

  test "failure message includes review hint" do
    message = Insta::Diff.failure_message("expected\n", "actual\n", "test")

    assert_includes message, "bundle exec insta review"
  end

  test "failure message uses minitest cli command" do
    caller_line = "test/my_test.rb:42:in 'test_something'"
    message = Insta::Diff.failure_message("expected\n", "actual\n", "test", nil, caller_line)

    assert_includes message, "bundle exec minitest test/my_test.rb:42"
  end

  test "run_test_command parses caller location" do
    command = Insta::Diff.run_test_command("test/foo_test.rb:10:in 'test_bar'")

    assert_equal "bundle exec minitest test/foo_test.rb:10", command
  end
end
