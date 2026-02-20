# frozen_string_literal: true

module Insta
  module SnapshotContent
    #: (String) -> String
    def self.normalize(content)
      content
        .gsub("\r\n", "\n")
        .gsub("\r", "\n")
        .sub(/\n+\z/, "")
        .concat("\n")
    end

    #: (String, Integer) -> String
    def self.indent(content, level)
      prefix = " " * level
      content.each_line.map { |line|
        if line.strip.empty?
          "\n"
        else
          "#{prefix}#{line}"
        end
      }.join
    end

    #: (String) -> String
    def self.strip_indent(content)
      lines = content.split("\n", -1)
      non_empty = lines.reject { |l| l.strip.empty? }
      return content if non_empty.empty?

      min_indent = non_empty.map { |l| l.match(/^(\s*)/).to_a[1].to_s.length }.min || 0
      return content if min_indent.zero?

      lines.map { |l|
        if l.strip.empty?
          ""
        else
          l[min_indent..] || ""
        end
      }.join("\n")
    end
  end
end
