# frozen_string_literal: true

require_relative "../test_helper"

class SnapshotNameTest < Minitest::Spec
  test "sanitize removes special chars" do
    assert_equal "hello_world", Insta::SnapshotName.sanitize("hello world!")
  end

  test "sanitize collapses underscores" do
    assert_equal "hello_world", Insta::SnapshotName.sanitize("hello___world")
  end

  test "sanitize strips leading and trailing underscores" do
    assert_equal "hello", Insta::SnapshotName.sanitize("_hello_")
  end

  test "sanitize preserves valid chars" do
    assert_equal "test-file_name.snap", Insta::SnapshotName.sanitize("test-file_name.snap")
  end

  test "underscore camel case" do
    assert_equal "my_test_class", Insta::SnapshotName.underscore("MyTestClass")
  end

  test "underscore with modules" do
    assert_equal "my_module/my_class", Insta::SnapshotName.underscore("MyModule::MyClass")
  end

  test "underscore with acronyms" do
    assert_equal "html_parser", Insta::SnapshotName.underscore("HTMLParser")
  end

  test "strip_test_prefix removes test_ prefix" do
    assert_equal "hello_world", Insta::SnapshotName.strip_test_prefix("test_hello_world")
  end

  test "strip_test_prefix removes test_ with numeric counter" do
    assert_equal "hello world", Insta::SnapshotName.strip_test_prefix("test_0001_hello world")
  end

  test "strip_test_prefix leaves non-test names unchanged" do
    assert_equal "my_method", Insta::SnapshotName.strip_test_prefix("my_method")
  end

  test "derive strips test prefix" do
    name = Insta::SnapshotName.derive("test_boolean_attribute")

    assert_equal "boolean_attribute", name
  end

  test "derive strips test prefix with numeric counter" do
    name = Insta::SnapshotName.derive("test_0001_boolean attribute")

    assert_equal "boolean_attribute", name
  end

  test "derive with counter 1 has no suffix" do
    name = Insta::SnapshotName.derive("test_parsing", counter: 1)

    assert_equal "parsing", name
  end

  test "derive with counter 2 adds suffix" do
    name = Insta::SnapshotName.derive("test_parsing", counter: 2)

    assert_equal "parsing-2", name
  end

  test "derive with counter 3 adds suffix" do
    name = Insta::SnapshotName.derive("test_parsing", counter: 3)

    assert_equal "parsing-3", name
  end

  test "derive with options" do
    name = Insta::SnapshotName.derive("test_output", options: { mode: :strict })

    assert_match(/\Aoutput-[a-f0-9]{32}\z/, name)
  end

  test "derive with counter and options" do
    name = Insta::SnapshotName.derive("test_output", counter: 2, options: { mode: :strict })

    assert_match(/\Aoutput-2-[a-f0-9]{32}\z/, name)
  end
end
