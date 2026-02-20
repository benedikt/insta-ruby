# frozen_string_literal: true

module Insta
  class UpdateCoordinator
    #: (Symbol) -> void
    def initialize(mode)
      @mode = mode
    end

    #: (String, String) -> Symbol
    def resolve(expected, actual)
      return :keep if expected == actual

      case @mode
      when :force then :update
      when :new then expected.empty? ? :update : :fail
      when :no then :fail
      else :pending # :auto, :pending => default to creating .snap.new
      end
    end
  end
end
