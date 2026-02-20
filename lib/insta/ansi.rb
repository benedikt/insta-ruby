# frozen_string_literal: true

module Insta
  module ANSI
    private

    #: () -> bool
    def color?
      !ENV.key?("NO_COLOR") && $stdout.tty?
    end

    #: (String) -> String
    def bold(text) = $stdout.tty? ? "\e[1m#{text}\e[0m" : text

    #: (String) -> String
    def dim(text) = $stdout.tty? ? "\e[2m#{text}\e[0m" : text

    #: (String) -> String
    def red(text) = color? ? "\e[31m#{text}\e[0m" : text

    #: (String) -> String
    def green(text) = color? ? "\e[32m#{text}\e[0m" : text

    #: (String) -> String
    def yellow(text) = color? ? "\e[33m#{text}\e[0m" : text

    #: (String) -> String
    def cyan(text) = color? ? "\e[36m#{text}\e[0m" : text
  end
end
