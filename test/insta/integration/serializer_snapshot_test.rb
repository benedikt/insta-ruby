# frozen_string_literal: true

require_relative "../../test_helper"
require "tmpdir"
require "fileutils"

class SerializerSnapshotTest < Minitest::Spec
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
    path = File.join(@tmpdir, "serializer_snapshot_test", "#{name}.snap")

    Insta::Snapshot.parse(File.read(path))
  end

  test "hash with default serializer" do
    hash = { name: "Alice", age: 30 }
    assert_snapshot(hash, name: "hash_default")

    snapshot = read_snapshot("hash_default")
    assert_equal "#{hash}\n", snapshot.content
  end

  test "hash with json serializer" do
    assert_snapshot({ name: "Alice", age: 30 }, name: "hash_json", serializer: :json)

    snapshot = read_snapshot("hash_json")
    assert_equal <<~JSON, snapshot.content
      {
        "name": "Alice",
        "age": 30
      }
    JSON
  end

  test "hash with yaml serializer" do
    assert_snapshot({ "name" => "Alice", "age" => 30 }, name: "hash_yaml", serializer: :yaml)

    snapshot = read_snapshot("hash_yaml")
    assert_equal <<~YAML, snapshot.content
      ---
      name: Alice
      age: 30
    YAML
  end

  test "hash with inspect serializer" do
    hash = { name: "Alice" }
    assert_snapshot(hash, name: "hash_inspect", serializer: :inspect)

    snapshot = read_snapshot("hash_inspect")
    assert_equal "#{hash.inspect}\n", snapshot.content
  end

  test "array with json serializer" do
    assert_snapshot([1, "two", 3.0, nil, true], name: "array_json", serializer: :json)

    snapshot = read_snapshot("array_json")
    assert_equal <<~JSON, snapshot.content
      [
        1,
        "two",
        3.0,
        null,
        true
      ]
    JSON
  end

  test "array with yaml serializer" do
    assert_snapshot(["alice", "bob", "charlie"], name: "array_yaml", serializer: :yaml)

    snapshot = read_snapshot("array_yaml")
    assert_equal <<~YAML, snapshot.content
      ---
      - alice
      - bob
      - charlie
    YAML
  end

  test "nested hash with json serializer" do
    data = {
      user: {
        name: "Alice",
        address: { city: "Zurich", country: "CH" },
        tags: ["admin", "active"],
      },
    }
    assert_snapshot(data, name: "nested_json", serializer: :json)

    snapshot = read_snapshot("nested_json")
    assert_equal <<~JSON, snapshot.content
      {
        "user": {
          "name": "Alice",
          "address": {
            "city": "Zurich",
            "country": "CH"
          },
          "tags": [
            "admin",
            "active"
          ]
        }
      }
    JSON
  end

  test "object with default serializer" do
    object = Struct.new(:name, :score).new("Alice", 42)
    assert_snapshot(object, name: "struct_default")

    snapshot = read_snapshot("struct_default")
    assert_equal "#<struct name=\"Alice\", score=42>\n", snapshot.content
  end

  test "object with inspect serializer" do
    object = Struct.new(:name, :score).new("Alice", 42)
    assert_snapshot(object, name: "struct_inspect", serializer: :inspect)

    snapshot = read_snapshot("struct_inspect")
    assert_equal "#<struct name=\"Alice\", score=42>\n", snapshot.content
  end

  test "object with json serializer via to_json" do
    klass = Struct.new(:name, :score) do
      def to_json(*args)
        { name: name, score: score }.to_json(*args)
      end
    end

    assert_snapshot(klass.new("Alice", 42), name: "struct_json", serializer: :json)

    snapshot = read_snapshot("struct_json")
    assert_equal <<~JSON, snapshot.content
      {
        "name": "Alice",
        "score": 42
      }
    JSON
  end

  test "hash snapshot matches on second run" do
    data = { items: [1, 2, 3], total: 3 }
    assert_snapshot(data, name: "hash_match", serializer: :json)
    assert_snapshot(data, name: "hash_match", serializer: :json)
  end

  test "array snapshot detects change" do
    assert_snapshot([1, 2, 3], name: "array_change", serializer: :json)
    assert_snapshot([1, 2, 3, 4], name: "array_change", serializer: :json)

    snapshot = read_snapshot("array_change")
    assert_equal <<~JSON, snapshot.content
      [
        1,
        2,
        3,
        4
      ]
    JSON
  end

  test "expression is stored in snap file metadata" do
    assert_snapshot(42, name: "expression_integer")

    snapshot = read_snapshot("expression_integer")
    assert_equal "Integer", snapshot.expression
  end

  test "type mismatch is detected" do
    assert_snapshot("2", name: "type_mismatch")

    Insta.configure { |c| c.update_mode = :no }

    error = assert_raises(Minitest::Assertion) do
      assert_snapshot(2, name: "type_mismatch")
    end

    assert_includes error.message, "Snapshot type mismatch"
    assert_includes error.message, "String"
    assert_includes error.message, "Integer"
  end
end
