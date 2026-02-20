# frozen_string_literal: true

require "prism"
require "tempfile"

module Insta
  module Inline
    class FilePatcher
      #: (String, Array[Inline::pending_entry]) -> String
      def self.patch(file_path, pending_entries)
        source = File.read(file_path)
        result = Prism.parse(source)
        edits = [] #: Array[Edit]

        pending_entries.each do |entry|
          line = entry[:line]
          content = entry[:content]
          type = entry[:type]

          finder = CallFinder.new(line)
          finder.visit(result.value)

          call = finder.found_call
          next unless call

          edit = build_edit(source, call, content, type)
          edits << edit if edit
        end

        apply_edits(source, edits)
      end

      #: (String, Array[Edit]) -> String
      def self.apply_edits(source, edits)
        sorted = edits.sort_by { |e| -e.start_offset }
        result = source.dup

        sorted.each do |edit|
          before = result.byteslice(0, edit.start_offset) || ""
          after = result.byteslice(edit.end_offset..) || ""
          result = before + edit.replacement + after
        end

        result
      end

      #: (String, Prism::CallNode, String, Symbol) -> Edit?
      def self.build_edit(source, call, content, type)
        arguments = call.arguments

        return build_insert_edit(source, call, content) if type == :insert || arguments.nil? || arguments.arguments.empty?

        snapshot_arg = find_snapshot_argument(arguments)
        return build_insert_edit(source, call, content) unless snapshot_arg

        if heredoc_node?(snapshot_arg)
          if single_line?(content)
            build_heredoc_to_string_edit(source, _ = snapshot_arg, content)
          else
            build_heredoc_edit(source, _ = snapshot_arg, content)
          end
        elsif snapshot_arg.is_a?(Prism::StringNode)
          if single_line?(content)
            build_string_edit(snapshot_arg, content)
          else
            build_string_to_heredoc_edit(source, call, snapshot_arg, content)
          end
        end
      end

      #: (Prism::Node) -> bool
      def self.heredoc_node?(node)
        case node
        when Prism::InterpolatedStringNode
          true
        when Prism::StringNode
          opening = node.opening_loc

          opening ? opening.slice.start_with?("<<") : false
        else
          false
        end
      end

      #: (Prism::ArgumentsNode) -> Prism::Node?
      def self.find_snapshot_argument(arguments)
        args = arguments.arguments

        positional_strings = args.select { |arg|
          case arg
          when Prism::StringNode, Prism::InterpolatedStringNode
            true
          else
            false
          end
        }

        positional_strings.last
      end

      #: (Prism::StringNode, String) -> Edit?
      def self.build_string_edit(node, content)
        content_location = node.content_loc
        return nil unless content_location

        trimmed = content.chomp

        Edit.new(content_location.start_offset, content_location.end_offset, trimmed)
      end

      #: (String, Prism::StringNode | Prism::InterpolatedStringNode, String) -> Edit?
      def self.build_heredoc_edit(source, node, content)
        opening = node.opening_loc
        closing = node.closing_loc
        return nil unless opening && closing

        content_start = source.b.index("\n".b, opening.end_offset)
        return nil unless content_start

        indent = closing.slice[/\A(\s*)/, 1].to_s.length
        indented_content = SnapshotContent.indent(content, indent + 2)

        Edit.new(content_start + 1, closing.start_offset, indented_content)
      end

      #: (String, Prism::StringNode | Prism::InterpolatedStringNode, String) -> Edit?
      def self.build_heredoc_to_string_edit(source, node, content)
        opening = node.opening_loc
        closing = node.closing_loc
        return nil unless opening && closing

        newline_position = source.b.index("\n".b, opening.end_offset)
        return nil unless newline_position

        suffix = source.byteslice(opening.end_offset, newline_position - opening.end_offset) || ""
        replacement = "#{content.chomp.inspect}#{suffix}\n"

        Edit.new(opening.start_offset, closing.end_offset, replacement)
      end

      #: (String, Prism::CallNode, Prism::StringNode, String) -> Edit?
      def self.build_string_to_heredoc_edit(source, call, node, content)
        opening = node.opening_loc
        closing_quote = node.closing_loc
        return nil unless opening && closing_quote

        heredoc_id = Insta.configuration.heredoc_identifier
        indent = detect_indent(source, call.location.start_offset)
        indented_content = SnapshotContent.indent(content, indent + 2)
        newline_position = source.b.index("\n".b, closing_quote.end_offset)
        return nil unless newline_position

        suffix = source.byteslice(closing_quote.end_offset, newline_position - closing_quote.end_offset) || ""
        replacement = "<<~#{heredoc_id}#{suffix}\n#{indented_content}#{" " * indent}#{heredoc_id}\n"

        Edit.new(opening.start_offset, newline_position + 1, replacement)
      end

      #: (String, Prism::CallNode, String) -> Edit?
      def self.build_insert_edit(source, call, content)
        closing = call.closing_loc

        unless closing
          location = call.location
          return build_bare_call_insert_edit(source, call, location, content)
        end

        if single_line?(content)
          build_insert_string_edit(call, closing, content)
        else
          build_insert_heredoc_edit(source, call, closing, content)
        end
      end

      #: (String, Prism::CallNode, Prism::Location, String) -> Edit
      def self.build_bare_call_insert_edit(source, call, location, content)
        if single_line?(content)
          replacement = "(#{content.chomp.inspect})"
        else
          heredoc_id = Insta.configuration.heredoc_identifier
          indent = detect_indent(source, call.location.start_offset)
          indented_content = SnapshotContent.indent(content, indent + 2)
          replacement = "(<<~#{heredoc_id})\n#{indented_content}#{" " * indent}#{heredoc_id}"
        end

        Edit.new(location.end_offset, location.end_offset, replacement)
      end

      #: (String) -> bool
      def self.single_line?(content)
        content.chomp.count("\n").zero?
      end

      #: (Prism::CallNode, Prism::Location, String) -> Edit
      def self.build_insert_string_edit(call, closing, content)
        trimmed = content.chomp.inspect
        arguments = call.arguments
        has_args = arguments && !arguments.arguments.empty?

        replacement = has_args ? ", #{trimmed})" : "(#{trimmed})"

        if has_args
          Edit.new(closing.start_offset, closing.end_offset, replacement)
        else
          opening = call.opening_loc
          start = opening ? opening.start_offset : closing.start_offset

          Edit.new(start, closing.end_offset, replacement)
        end
      end

      #: (String, Prism::CallNode, Prism::Location, String) -> Edit
      def self.build_insert_heredoc_edit(source, call, closing, content)
        heredoc_id = Insta.configuration.heredoc_identifier
        indent = detect_indent(source, call.location.start_offset)
        indented_content = SnapshotContent.indent(content, indent + 2)

        arguments = call.arguments
        has_args = arguments && !arguments.arguments.empty?

        replacement = if has_args
                        ", <<~#{heredoc_id})\n#{indented_content}#{" " * indent}#{heredoc_id}"
                      else
                        "(<<~#{heredoc_id})\n#{indented_content}#{" " * indent}#{heredoc_id}"
                      end

        if has_args
          Edit.new(closing.start_offset, closing.end_offset, replacement)
        else
          opening = call.opening_loc
          start = opening ? opening.start_offset : closing.start_offset

          Edit.new(start, closing.end_offset, replacement)
        end
      end

      #: (String, Integer) -> Integer
      def self.detect_indent(source, offset)
        line_start = source.b.rindex("\n".b, offset)
        line_start = line_start ? line_start + 1 : 0
        line_content = source.byteslice(line_start, offset - line_start) || ""

        line_content.match(/^(\s*)/).to_a[1].to_s.length
      end

      #: (String, String) -> void
      def self.atomic_write(file_path, content)
        directory = File.dirname(file_path)

        temp = Tempfile.new("insta", directory)
        temp.write(content)
        temp.close

        File.rename(temp.path.to_s, file_path)
      rescue StandardError
        temp&.unlink
        raise
      end

      private_class_method :build_edit, :heredoc_node?, :find_snapshot_argument,
                           :build_string_edit, :build_heredoc_edit,
                           :build_heredoc_to_string_edit, :build_string_to_heredoc_edit,
                           :build_insert_edit, :build_bare_call_insert_edit,
                           :single_line?,
                           :build_insert_string_edit, :build_insert_heredoc_edit,
                           :detect_indent
    end
  end
end
