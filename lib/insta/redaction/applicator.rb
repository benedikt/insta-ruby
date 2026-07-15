# frozen_string_literal: true

module Insta
  module Redaction
    class Applicator
      #: (untyped, Hash[String, untyped]?) -> untyped
      def self.apply(value, redactions)
        return value if redactions.nil? || redactions.empty?

        unless value.is_a?(Hash) || value.is_a?(Array)
          raise ArgumentError,
                "Redactions require structured data (Hash or Array), got #{value.class}. " \
                "Use a structured serializer like `serializer: :json` or `serializer: :yaml` with Hash/Array values."
        end

        duped = deep_dup(value)
        parsed = redactions.transform_keys { |key| Selector.new(key) }

        walk(duped, [], parsed)

        duped
      end

      #: (untyped) -> untyped
      def self.deep_dup(object)
        case object
        when Hash
          hash = {} #: Hash[untyped, untyped]
          object.each_with_object(hash) { |(key, value), result| result[key] = deep_dup(value) }
        when Array
          object.map { |value| deep_dup(value) }
        else
          object
        end
      end

      #: (untyped, untyped, Hash[Selector, untyped]) -> void
      def self.walk(node, path, parsed_redactions)
        case node
        when Hash
          node.each_key do |key|
            child_path = path + [{ type: :key, value: key }]
            replacement = find_match(child_path, parsed_redactions)

            if replacement
              node[key] = apply_replacement(node[key], replacement)
            else
              walk(node[key], child_path, parsed_redactions)
            end
          end
        when Array
          node.each_with_index do |_item, index|
            child_path = path + [{ type: :index, value: index }]
            replacement = find_match(child_path, parsed_redactions)

            if replacement
              node[index] = apply_replacement(node[index], replacement)
            else
              walk(node[index], child_path, parsed_redactions)
            end
          end
        end
      end

      #: (untyped, Hash[Selector, untyped]) -> untyped
      def self.find_match(path, parsed_redactions)
        parsed_redactions.each do |selector, replacement|
          return replacement if selector.matches?(path)
        end

        nil
      end

      #: (untyped, untyped) -> untyped
      def self.apply_replacement(value, replacement)
        case replacement
        when Proc
          replacement.call(value)
        when :sorted
          value.is_a?(Array) ? value.sort_by(&:to_s) : value
        else
          replacement
        end
      end

      private_class_method :deep_dup, :walk, :find_match, :apply_replacement
    end
  end
end
