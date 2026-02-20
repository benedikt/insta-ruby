# frozen_string_literal: true

require_relative "../../test_helper"
require "tmpdir"
require "fileutils"

class AssertionsTest < Minitest::Spec
  def setup
    super
    @tmpdir = Dir.mktmpdir
    Insta.configure do |config|
      config.snapshot_path = @tmpdir
      config.update_mode = :force
      config.new_snapshot = :auto
    end
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
    super
  end

  test "assert_snapshot creates new file" do
    assert_snapshot("hello world")

    snap_files = Dir.glob(File.join(@tmpdir, "**", "*.snap"))
    assert_equal 1, snap_files.length

    content = File.read(snap_files.first)
    assert_includes content, "hello world"
  end

  test "assert_snapshot matches existing" do
    assert_snapshot("hello world")
    assert_snapshot("hello world")
  end

  test "assert_snapshot with name" do
    assert_snapshot("hello", name: "greeting")

    snap_files = Dir.glob(File.join(@tmpdir, "**", "greeting.snap"))
    assert_equal 1, snap_files.length
  end

  test "assert_snapshot with metadata" do
    assert_snapshot("content", input: "<div>hi</div>", description: "A test")

    snap_files = Dir.glob(File.join(@tmpdir, "**", "*.snap"))
    content = File.read(snap_files.first)

    assert_includes content, "input:"
    assert_includes content, "description: A test"
  end

  test "assert_snapshot updates in force mode" do
    assert_snapshot("first version")

    snap_files = Dir.glob(File.join(@tmpdir, "**", "*.snap"))
    first_content = File.read(snap_files.first)
    assert_includes first_content, "first version"

    assert_snapshot("second version")
  end

  test "assert_snapshot fails in no mode when missing" do
    Insta.configure { |c| c.update_mode = :no }

    assert_raises(Minitest::Assertion) do
      assert_snapshot("hello")
    end
  end

  test "assert_snapshot with serializer" do
    assert_snapshot({ key: "value" }, serializer: :json)

    snap_files = Dir.glob(File.join(@tmpdir, "**", "*.snap"))
    content = File.read(snap_files.first)

    assert_includes content, '"key"'
    assert_includes content, '"value"'
  end
end
