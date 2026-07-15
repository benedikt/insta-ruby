# frozen_string_literal: true

module Insta
  module Redaction
    class Selector
      Segment = Struct.new(:type, :value, keyword_init: true) #: Struct[Symbol, untyped]

      SEGMENT_TYPES = [:key, :index, :wildcard, :deep_wildcard, :full_range].freeze #: Array[Symbol]

      attr_reader :segments #: Array[Segment]

      #: (String) -> void
      def initialize(selector_string)
        @segments = parse(selector_string)
      end

      #: (Array[{ type: Symbol, value: untyped }]) -> bool
      def matches?(path)
        deep_index = segments.index { |segment| segment.type == :deep_wildcard }

        if deep_index
          deep_wildcard_match?(path, deep_index)
        else
          exact_match?(path, segments)
        end
      end

      private

      #: (String) -> Array[Segment]
      def parse(input)
        raise ArgumentError, "Selector must not be empty" if input.empty?
        raise ArgumentError, "Selector must start with '.' or '['" unless input.start_with?(".", "[")

        result = [] #: Array[Segment]
        position = 0

        while position < input.length
          case input[position]
          when "."
            position = parse_dot_segment(input, position + 1, result)
          when "["
            position = parse_bracket_segment(input, position + 1, result)
          else
            raise ArgumentError, "Unexpected character '#{input[position]}' at position #{position}"
          end
        end

        result
      end

      #: (String, Integer, Array[Segment]) -> Integer
      def parse_dot_segment(input, position, result)
        if position < input.length && input[position] == "*"
          parse_wildcard_segment(input, position + 1, result)
        else
          parse_key_segment(input, position, result)
        end
      end

      #: (String, Integer, Array[Segment]) -> Integer
      def parse_wildcard_segment(input, position, result)
        if position < input.length && input[position] == "*"
          raise ArgumentError, "Only one deep wildcard (**) allowed per selector" if result.any? { |segment| segment.type == :deep_wildcard }

          result << Segment.new(type: :deep_wildcard, value: nil)

          position + 1
        else
          result << Segment.new(type: :wildcard, value: nil)

          position
        end
      end

      #: (String, Integer, Array[Segment]) -> Integer
      def parse_key_segment(input, position, result)
        key = +""

        while position < input.length && input[position] != "." && input[position] != "["
          key << input[position].to_s
          position += 1
        end

        raise ArgumentError, "Empty key in selector at position #{position}" if key.empty?

        result << Segment.new(type: :key, value: key)

        position
      end

      #: (String, Integer, Array[Segment]) -> Integer
      def parse_bracket_segment(input, position, result)
        if position < input.length && input[position] == "]"
          result << Segment.new(type: :full_range, value: nil)

          position + 1
        elsif position < input.length && input[position] == '"'
          parse_quoted_key_segment(input, position + 1, result)
        else
          parse_index_segment(input, position, result)
        end
      end

      #: (String, Integer, Array[Segment]) -> Integer
      def parse_quoted_key_segment(input, position, result)
        key = +""

        while position < input.length && input[position] != '"'
          key << input[position].to_s
          position += 1
        end

        raise ArgumentError, "Unterminated quoted key in selector" if position >= input.length

        position += 1
        raise ArgumentError, "Expected ']' after quoted key" if position >= input.length || input[position] != "]"

        result << Segment.new(type: :key, value: key)

        position + 1
      end

      #: (String, Integer, Array[Segment]) -> Integer
      def parse_index_segment(input, position, result)
        digits = +""

        while position < input.length && input[position] =~ /\d/
          digits << input[position].to_s
          position += 1
        end

        raise ArgumentError, "Expected number or ']' in bracket" if digits.empty?
        raise ArgumentError, "Expected ']' after index" if position >= input.length || input[position] != "]"

        result << Segment.new(type: :index, value: digits.to_i)

        position + 1
      end

      #: (Array[{ type: Symbol, value: untyped }], Integer) -> bool
      def deep_wildcard_match?(path, deep_index)
        before = segments[0...deep_index] || [] #: Array[Segment]
        after = segments[(deep_index + 1)..] || [] #: Array[Segment]

        return false if path.length < before.length + after.length

        before.each_with_index do |segment, index|
          return false unless segment_matches?(segment, path[index])
        end

        return true if after.empty?

        after_length = after.length
        path_length = path.length

        after.each_with_index do |segment, index|
          path_index = path_length - after_length + index
          return false unless segment_matches?(segment, path[path_index])
        end

        true
      end

      #: (Array[{ type: Symbol, value: untyped }], Array[Segment]) -> bool
      def exact_match?(path, expected_segments)
        return false unless path.length == expected_segments.length

        expected_segments.each_with_index do |segment, index|
          return false unless segment_matches?(segment, path[index])
        end

        true
      end

      #: (Segment, { type: Symbol, value: untyped }) -> bool
      def segment_matches?(segment, path_entry)
        case segment.type
        when :key
          path_entry[:type] == :key && path_entry[:value].to_s == segment.value
        when :index
          path_entry[:type] == :index && path_entry[:value] == segment.value
        when :wildcard
          path_entry[:type] == :key
        when :full_range
          path_entry[:type] == :index
        else
          false
        end
      end
    end
  end
end
