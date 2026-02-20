# frozen_string_literal: true

require "pathname"
require "fileutils"

module Insta
  class SnapshotFile
    attr_reader :base_path #: Pathname
    attr_reader :extension #: String

    #: (String, String, String, ?String?) -> void
    def initialize(base_path, test_class, test_name, extension = nil)
      directory_resolver = Insta.configuration.snapshot_directory
      directory = if directory_resolver
                    directory_resolver.call(test_class: test_class)
                  else
                    SnapshotName.underscore(test_class)
                  end
      @base_path = Pathname.new(base_path) / directory
      @test_name = test_name
      @extension = extension || Insta.configuration.snapshot_extension
      @counter = 0
    end

    #: (?Hash[Symbol, untyped]) -> Pathname
    def path_for(options = {})
      @counter += 1
      filename_resolver = Insta.configuration.snapshot_filename

      derived = if filename_resolver
                  filename_resolver.call(test_name: @test_name, counter: @counter, options: options)
                else
                  SnapshotName.derive(@test_name, counter: @counter, options: options)
                end

      @base_path / "#{derived}#{@extension}"
    end

    #: (String) -> Pathname
    def named_path(name)
      @base_path / "#{SnapshotName.sanitize(name)}#{@extension}"
    end

    #: (Pathname) -> Pathname
    def pending_path(path)
      Pathname.new("#{path}.new")
    end

    #: (Pathname, String, Snapshot::snapshot_metadata) -> void
    def write(path, content, metadata = {})
      FileUtils.mkdir_p(path.dirname)
      snapshot = Snapshot.new(content, metadata)

      path.write(snapshot.serialize)
    end

    #: (Pathname) -> Snapshot?
    def read(path)
      return nil unless path.exist?

      Snapshot.parse(path.read)
    end
  end
end
