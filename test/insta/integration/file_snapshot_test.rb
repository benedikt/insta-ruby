# frozen_string_literal: true

require_relative "../../test_helper"
require "tmpdir"
require "fileutils"

class FileSnapshotIntegrationTest < Minitest::Spec
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

  test "full lifecycle create match update" do
    assert_snapshot("version 1", name: "lifecycle")

    path = File.join(@tmpdir, "file_snapshot_integration_test", "lifecycle.snap")
    assert File.exist?(path), "Expected snapshot file to exist"

    assert_snapshot("version 1", name: "lifecycle")

    assert_snapshot("version 2", name: "lifecycle")

    content = File.read(path)
    assert_includes content, "version 2"
  end

  test "snapshot with yaml frontmatter" do
    assert_snapshot("output content", input: "<div>hello</div>", description: "Parsing test")

    snap_files = Dir.glob(File.join(@tmpdir, "**", "*.snap"))
    snapshot = Insta::Snapshot.parse(File.read(snap_files.first))

    assert_equal "output content\n", snapshot.content
    assert_includes snapshot.source, "FileSnapshotIntegrationTest"
    assert_equal "<div>hello</div>", snapshot.input
    assert_equal "Parsing test", snapshot.description
  end

  test "named snapshot" do
    assert_snapshot("named content", name: "my_custom_snapshot")

    path = File.join(@tmpdir, "file_snapshot_integration_test", "my_custom_snapshot.snap")
    assert File.exist?(path), "Expected snapshot at #{path}"
  end

  test "pending mode writes .snap.new and fails" do
    Insta.configure { |c| c.update_mode = :force }
    assert_snapshot("original", name: "pending_test")

    Insta.configure { |c| c.update_mode = :pending }

    assert_raises(Minitest::Assertion) do
      assert_snapshot("updated", name: "pending_test")
    end

    pending_files = Dir.glob(File.join(@tmpdir, "**", "*.snap.new"))
    assert_equal 1, pending_files.length
  end

  test "pending mode with INSTA_FORCE_PASS writes .snap.new and passes" do
    Insta.configure { |c| c.update_mode = :force }
    assert_snapshot("original", name: "pending_force_pass_test")

    Insta.configure { |c| c.update_mode = :pending }

    ENV["INSTA_FORCE_PASS"] = "1"
    assert_snapshot("updated", name: "pending_force_pass_test")

    pending_files = Dir.glob(File.join(@tmpdir, "**", "*.snap.new"))
    assert_equal 1, pending_files.length
  ensure
    ENV.delete("INSTA_FORCE_PASS")
  end

  test "multiple snapshots in one test" do
    assert_snapshot("output_a", name: "multi_a")
    assert_snapshot("output_b", name: "multi_b")

    a_path = File.join(@tmpdir, "file_snapshot_integration_test", "multi_a.snap")
    b_path = File.join(@tmpdir, "file_snapshot_integration_test", "multi_b.snap")

    assert File.exist?(a_path)
    assert File.exist?(b_path)
  end

  test "multiple unnamed snapshots in one test" do
    assert_snapshot("first output")
    assert_snapshot("second output")
    assert_snapshot("third output")

    snap_files = Dir.glob(File.join(@tmpdir, "file_snapshot_integration_test", "*.snap"))
    assert_equal 3, snap_files.length

    basenames = snap_files.map { |f| File.basename(f) }
    assert_includes basenames, "multiple_unnamed_snapshots_in_one_test.snap"
    assert_includes basenames, "multiple_unnamed_snapshots_in_one_test-2.snap"
    assert_includes basenames, "multiple_unnamed_snapshots_in_one_test-3.snap"
  end

  test "custom snapshot_filename" do
    Insta.configure do |config|
      config.snapshot_filename = lambda { |test_name:, counter:, options:|
        derived = Insta::SnapshotName.derive(test_name, counter: counter, options: options)
        "snap_#{derived}"
      }
    end

    assert_snapshot("custom filename output")

    snap_files = Dir.glob(File.join(@tmpdir, "file_snapshot_integration_test", "*.snap"))
    basenames = snap_files.map { |f| File.basename(f) }
    assert_includes basenames, "snap_custom_snapshot_filename.snap"
  ensure
    Insta.configuration.snapshot_filename = nil
  end

  test "custom snapshot_directory" do
    Insta.configure do |config|
      config.snapshot_directory = ->(test_class:) { "custom/#{Insta::SnapshotName.underscore(test_class)}" }
    end

    assert_snapshot("custom directory output", name: "dir_test")

    path = File.join(@tmpdir, "custom", "file_snapshot_integration_test", "dir_test.snap")
    assert File.exist?(path), "Expected snapshot at #{path}"
  ensure
    Insta.configuration.snapshot_directory = nil
  end

  test "custom snapshot_directory with flat structure" do
    Insta.configure do |config|
      config.snapshot_directory = ->(**) { "" }
    end

    assert_snapshot("flat output", name: "flat_test")

    path = File.join(@tmpdir, "flat_test.snap")
    assert File.exist?(path), "Expected snapshot at #{path}"
  ensure
    Insta.configuration.snapshot_directory = nil
  end

  test "json serializer" do
    data = { "name" => "test", "items" => [1, 2, 3] }
    assert_snapshot(data, name: "json_test", serializer: :json)

    path = File.join(@tmpdir, "file_snapshot_integration_test", "json_test.snap")
    content = File.read(path)

    assert_includes content, '"name": "test"'
    assert_includes content, '"items"'
  end
end
