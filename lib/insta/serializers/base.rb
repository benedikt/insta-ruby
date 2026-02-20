# frozen_string_literal: true

module Insta
  module Serializers
    class Base
      #: (untyped) -> String
      def self.serialize(value)
        raise NotImplementedError, "#{name} must implement .serialize"
      end
    end

    REGISTRY = {} #: Hash[Symbol, singleton(Base)] # rubocop:disable Style/MutableConstant

    #: (Symbol, singleton(Base)) -> void
    def self.register(name, serializer)
      REGISTRY[name] = serializer
    end

    #: (Symbol) -> singleton(Base)
    def self.fetch(name)
      REGISTRY.fetch(name) do
        raise ArgumentError, "Unknown serializer: #{name.inspect}. Available: #{REGISTRY.keys.join(", ")}"
      end
    end

    #: (Symbol, untyped) -> String
    def self.serialize(name, value)
      fetch(name).serialize(value)
    end
  end
end
