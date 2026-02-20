# frozen_string_literal: true

require "json"

module Insta
  module Serializers
    class JSONSerializer < Base
      #: (untyped) -> String
      def self.serialize(value)
        JSON.pretty_generate(value)
      end
    end

    register(:json, JSONSerializer)
  end
end
