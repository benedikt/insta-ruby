# frozen_string_literal: true

require_relative "../../test_helper"
require "tmpdir"
require "fileutils"
require "securerandom"

class RedactionSnapshotTest < Minitest::Spec
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

  def read_snapshot(name)
    path = File.join(@tmpdir, "redaction_snapshot_test", "#{name}.snap")

    Insta::Snapshot.parse(File.read(path))
  end

  test "assert_snapshot with JSON and redaction" do
    data = { "id" => "abc-123", "name" => "Alice" }
    assert_snapshot(data, name: "json_redact", serializer: :json, redact: { ".id" => "[uuid]" })

    snapshot = read_snapshot("json_redact")
    assert_includes snapshot.content, '"id": "[uuid]"'
    assert_includes snapshot.content, '"name": "Alice"'
    refute_includes snapshot.content, "abc-123"
  end

  test "same UUID redacted on two runs produces matching snapshot" do
    uuid1 = SecureRandom.uuid
    data1 = { "id" => uuid1, "name" => "Alice" }
    assert_snapshot(data1, name: "uuid_stable", serializer: :json, redact: { ".id" => "[uuid]" })

    uuid2 = SecureRandom.uuid
    data2 = { "id" => uuid2, "name" => "Alice" }
    assert_snapshot(data2, name: "uuid_stable", serializer: :json, redact: { ".id" => "[uuid]" })
  end

  test "multiple redactions" do
    data = { "id" => "abc", "created_at" => "2024-01-01T00:00:00Z", "name" => "Alice" }
    assert_snapshot(data, name: "multi_redact", serializer: :json, redact: {
      ".id" => "[uuid]",
      ".created_at" => "[timestamp]",
    })

    snapshot = read_snapshot("multi_redact")
    assert_includes snapshot.content, '"id": "[uuid]"'
    assert_includes snapshot.content, '"created_at": "[timestamp]"'
    assert_includes snapshot.content, '"name": "Alice"'
  end

  test "deep wildcard end to end" do
    data = {
      "user" => {
        "id" => "u1",
        "profile" => { "id" => "p1", "name" => "Alice" },
      },
    }
    assert_snapshot(data, name: "deep_wildcard", serializer: :json, redact: { ".**.id" => "[uuid]" })

    snapshot = read_snapshot("deep_wildcard")
    refute_includes snapshot.content, "u1"
    refute_includes snapshot.content, "p1"
    assert_includes snapshot.content, '"name": "Alice"'
  end

  test "array wildcard .items[].id" do
    data = {
      "items" => [
        { "id" => "a1", "name" => "Item A" },
        { "id" => "b2", "name" => "Item B" }
      ],
    }
    assert_snapshot(data, name: "array_wildcard", serializer: :json, redact: { ".items[].id" => "[uuid]" })

    snapshot = read_snapshot("array_wildcard")
    refute_includes snapshot.content, "a1"
    refute_includes snapshot.content, "b2"
    assert_includes snapshot.content, '"name": "Item A"'
    assert_includes snapshot.content, '"name": "Item B"'
  end

  test "raises for non-structured data with to_s serializer" do
    error = assert_raises(ArgumentError) do
      assert_snapshot("plain string", name: "should_fail", serializer: :to_s, redact: { ".id" => "[uuid]" })
    end

    assert_includes error.message, "Redactions require structured data (Hash or Array), got String"
    assert_includes error.message, "serializer: :json"
  end

  test "raises for non-structured data with inspect serializer" do
    error = assert_raises(ArgumentError) do
      assert_snapshot(42, name: "should_fail", serializer: :inspect, redact: { ".id" => "[uuid]" })
    end

    assert_includes error.message, "Redactions require structured data (Hash or Array), got Integer"
    assert_includes error.message, "serializer: :json"
  end

  test "proc through pipeline" do
    data = { "score" => 3.14159, "name" => "Alice" }
    assert_snapshot(data, name: "proc_redact", serializer: :json, redact: {
      ".score" => ->(v) { v.round(2) },
    })

    snapshot = read_snapshot("proc_redact")
    assert_includes snapshot.content, "3.14"
    refute_includes snapshot.content, "3.14159"
  end

  test "sorted through pipeline" do
    data = { "tags" => ["charlie", "alice", "bob"] }
    assert_snapshot(data, name: "sorted_redact", serializer: :json, redact: {
      ".tags" => :sorted,
    })

    snapshot = read_snapshot("sorted_redact")
    content = snapshot.content
    alice_pos = content.index("alice")
    bob_pos = content.index("bob")
    charlie_pos = content.index("charlie")
    assert alice_pos < bob_pos
    assert bob_pos < charlie_pos
  end

  test "symbol keys work with redactions" do
    data = { id: "abc-123", name: "Alice" }
    assert_snapshot(data, name: "symbol_keys", serializer: :json, redact: { ".id" => "[uuid]" })

    snapshot = read_snapshot("symbol_keys")
    assert_includes snapshot.content, '"id": "[uuid]"'
    refute_includes snapshot.content, "abc-123"
  end
end
