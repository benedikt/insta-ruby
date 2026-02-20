# frozen_string_literal: true

module Insta
  module Inline
    # @rbs!
    #   type pending_entry = { line: Integer, content: String, type: Symbol }

    class Edit
      attr_reader :start_offset #: Integer
      attr_reader :end_offset #: Integer
      attr_reader :replacement #: String

      #: (Integer, Integer, String) -> void
      def initialize(start_offset, end_offset, replacement)
        @start_offset = start_offset
        @end_offset = end_offset
        @replacement = replacement
      end
    end
  end
end
