# frozen_string_literal: true

require "yaml"

module Insta
  class Snapshot
    # @rbs!
    #   type snapshot_metadata = Hash[String, untyped]

    SEPARATOR = "---" #: String

    attr_reader :content #: String
    attr_reader :metadata #: snapshot_metadata

    #: (String, ?snapshot_metadata) -> void
    def initialize(content, metadata = {})
      @content = content
      @metadata = metadata
    end

    #: (String) -> Snapshot
    def self.parse(raw)
      raw = raw.to_s

      if raw.start_with?("#{SEPARATOR}\n")
        parts = raw.split("#{SEPARATOR}\n", 3)

        if parts.length >= 3
          metadata = begin
            YAML.safe_load(parts[1], permitted_classes: [Symbol]) || {}
          rescue Psych::SyntaxError
            {} #: snapshot_metadata
          end

          return new(parts[2].chomp.concat("\n"), metadata)
        end
      end

      new(raw, {})
    end

    #: () -> String
    def serialize
      return @content if @metadata.empty?

      YAML.dump(@metadata) + "#{SEPARATOR}\n" + @content
    end

    #: () -> String?
    def source
      @metadata["source"]
    end

    #: () -> String?
    def input
      @metadata["input"]
    end

    #: () -> String?
    def description
      @metadata["description"]
    end

    #: () -> String?
    def expression
      @metadata["expression"]
    end

    #: () -> Hash[String, untyped]?
    def info
      @metadata["info"]
    end
  end
end
