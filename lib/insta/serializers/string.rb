# frozen_string_literal: true

module Insta
  module Serializers
    class StringSerializer < Base
      #: (untyped) -> String
      def self.serialize(value)
        value.to_s
      end
    end

    register(:to_s, StringSerializer)
  end
end
