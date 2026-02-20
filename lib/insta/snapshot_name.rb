# frozen_string_literal: true

require "digest"

module Insta
  module SnapshotName
    #: (String) -> String
    def self.sanitize(name)
      sanitizer = Insta.configuration.snapshot_sanitizer

      if sanitizer
        sanitizer.call(name)
      else
        name
          .gsub(/[^a-zA-Z0-9_\-.]/, "_")
          .gsub(/_+/, "_")
          .gsub(/\A_|_\z/, "")
      end
    end

    #: (String) -> String
    def self.underscore(string)
      string
        .gsub("::", "/")
        .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
        .gsub(/([a-z\d])([A-Z])/, '\1_\2')
        .tr("-", "_")
        .tr(" ", "_")
        .downcase
    end

    #: (String) -> String
    def self.strip_test_prefix(name)
      name.sub(/\Atest_(\d+_)?/, "")
    end

    #: (String, ?counter: Integer, ?options: Hash[Symbol, untyped]) -> String
    def self.derive(test_name, counter: 1, options: {})
      stripped = strip_test_prefix(test_name)
      clean_name = sanitize(stripped)
      suffix = counter > 1 ? "-#{counter}" : ""

      if options && !options.empty?
        options_hash = Digest::MD5.hexdigest(options.inspect)
        "#{clean_name}#{suffix}-#{options_hash}"
      else
        "#{clean_name}#{suffix}"
      end
    end
  end
end
