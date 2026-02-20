# frozen_string_literal: true

begin
  require "irb/color"
rescue LoadError
  # irb not available, syntax highlighting will be skipped
end

module Insta
  class SyntaxHighlight
    #: (String, ?colorable: bool) -> String
    def self.highlight(code, colorable: true)
      return code unless colorable && defined?(IRB::Color)

      IRB::Color.colorize_code(code, complete: false, colorable: true)
    rescue StandardError
      code
    end
  end
end
