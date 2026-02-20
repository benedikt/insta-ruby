# frozen_string_literal: true

require "yaml"

module Insta
  module Serializers
    class YAMLSerializer < Base
      #: (untyped) -> String
      def self.serialize(value)
        YAML.dump(value)
      end
    end

    register(:yaml, YAMLSerializer)
  end
end
