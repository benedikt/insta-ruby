# frozen_string_literal: true

module Insta
  module Minitest
    module Lifecycle
      #: (Module) -> void
      def self.included(base)
        base.include(Assertions)
      end
    end
  end
end
