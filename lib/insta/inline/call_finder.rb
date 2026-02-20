# frozen_string_literal: true

require "prism"

module Insta
  module Inline
    class CallFinder < Prism::Visitor
      METHODS = [:assert_inline_snapshot, :match_inline_snapshot].freeze #: Array[Symbol]

      attr_reader :found_call #: Prism::CallNode?

      #: (Integer) -> void
      def initialize(target_line)
        super()

        @target_line = target_line
        @found_call = nil
      end

      #: (Prism::CallNode) -> void
      def visit_call_node(node)
        @found_call = node if METHODS.include?(node.name) && covers_line?(node)

        super
      end

      private

      #: (Prism::Node) -> bool
      def covers_line?(node)
        location = node.location

        @target_line.between?(location.start_line, location.end_line)
      end
    end
  end
end
