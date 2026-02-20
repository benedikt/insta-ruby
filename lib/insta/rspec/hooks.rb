# frozen_string_literal: true

module Insta
  module RSpec
    module Hooks
      #: () -> void
      def self.install!
        ::RSpec.configure do |config|
          config.include(Matchers)

          config.after(:suite) do
            PendingReporter.flush_and_report!
          end
        end
      end
    end
  end
end
