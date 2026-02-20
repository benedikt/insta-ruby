# frozen_string_literal: true

module Insta
  module Serializers
    class InspectSerializer < Base
      #: (untyped) -> String
      def self.serialize(value)
        value.inspect
      end
    end

    register(:inspect, InspectSerializer)
  end
end
