# frozen_string_literal: true

require "json"

module Insta
  module PendingLocations
    FILENAME = ".insta-pending-locations"

    @locations = {} #: Hash[String, String]
    @mutex = Mutex.new

    #: (String, String) -> void
    def self.add(path, caller_line)
      @mutex.synchronize do
        @locations[path] = caller_line
      end
    end

    #: () -> void
    def self.flush!
      entries = @mutex.synchronize do
        result = @locations.dup
        @locations.clear
        result
      end

      return if entries.empty?

      manifest_path = File.join(Insta.configuration.snapshot_path, FILENAME)
      existing = if File.exist?(manifest_path)
                   JSON.parse(File.read(manifest_path))
                 else
                   {} #: Hash[String, String]
                 end

      existing.merge!(entries)

      FileUtils.mkdir_p(File.dirname(manifest_path))
      File.write(manifest_path, JSON.pretty_generate(existing))
    end

    #: () -> Hash[String, String]
    def self.load
      manifest_path = File.join(Insta.configuration.snapshot_path, FILENAME)
      return {} unless File.exist?(manifest_path)

      JSON.parse(File.read(manifest_path))
    rescue JSON::ParserError
      {}
    end

    #: () -> void
    def self.clean!
      manifest_path = File.join(Insta.configuration.snapshot_path, FILENAME)

      FileUtils.rm_f(manifest_path)
    end

    #: () -> void
    def self.clear!
      @mutex.synchronize { @locations.clear }
    end
  end
end
