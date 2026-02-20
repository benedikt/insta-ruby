# frozen_string_literal: true

require "difftastic"

module Insta
  class Diff
    #: () -> Difftastic::Differ
    def self.differ
      config = Insta.configuration

      Difftastic::Differ.new(
        color: config.resolved_diff_color.to_sym,
        display: config.resolved_diff_display,
        width: config.diff_width,
        left_label: "Expected",
        right_label: "Actual"
      )
    end

    #: (String, String) -> String
    def self.diff(expected, actual)
      differ.diff_strings(expected, actual)
    end

    #: (String, String, ?file_extension: String?) -> String
    def self.diff_with_language(expected, actual, file_extension: nil)
      if file_extension
        differ.diff_strings(expected, actual, file_extension: file_extension)
      else
        differ.diff_strings(expected, actual)
      end
    end

    #: (String, String, String, ?String?, ?String?, ?file_extension: String?) -> String
    def self.failure_message(expected, actual, test_name, snapshot_path = nil, line = nil, file_extension: nil)
      dim = "\e[2m"
      cyan = "\e[36m"
      reset = "\e[0m"
      divider = "#{dim}#{"─" * terminal_width}#{reset}"

      message = +""
      message << "#{reset}\n"
      message << "Snapshot for #{cyan}\"#{test_name}\"#{reset} didn't match.\n"
      message << "\n"
      message << "  #{dim}Snapshot:#{reset} #{snapshot_path}\n" if snapshot_path
      message << "  #{dim}Test:#{reset}     #{caller_file_location(line)}\n" if line
      message << "\n"
      message << "#{divider}\n"
      message << diff_with_language(expected, actual, file_extension: file_extension)
      message << "\n#{divider}\n"
      message << "\n"

      if line
        message << "  #{dim}Update snapshot and re-run this test:#{reset}\n"
        message << "  #{cyan}INSTA_UPDATE=force #{run_test_command(line)}#{reset}\n"
        message << "\n"
      end

      message << "  #{dim}Interactively review all pending snapshots:#{reset}\n"
      message << "  #{cyan}bundle exec insta review#{reset}\n"
      message << "\n#{divider}\n"
      message << reset

      message
    end

    #: (String) -> String
    def self.caller_file_location(caller_line)
      file, lineno = caller_line.split(":", 3).first(2)

      file && lineno ? "#{file}:#{lineno}" : caller_line
    end

    #: (String) -> String
    def self.run_test_command(caller_line)
      file, lineno = caller_line.split(":", 3).first(2)

      if rspec?
        "bundle exec rspec #{file}:#{lineno}"
      elsif rails?
        "bin/rails test #{file}:#{lineno}"
      elsif minitest_cli?
        "bundle exec minitest #{file}:#{lineno}"
      elsif mtest?
        "bundle exec mtest #{file}:#{lineno}"
      else
        "bundle exec ruby -Itest #{file}"
      end
    end

    #: () -> bool
    def self.rspec?
      return @rspec if defined?(@rspec)

      @rspec = !!defined?(::RSpec)
    end

    #: () -> bool
    def self.rails?
      return @rails if defined?(@rails)

      @rails = !!(defined?(::Rails) && defined?(::ActiveSupport::TestCase))
    end

    #: () -> bool
    def self.minitest_cli?
      return @minitest_cli if defined?(@minitest_cli)

      @minitest_cli = !!(defined?(::Minitest::VERSION) && Gem::Version.new(::Minitest::VERSION) >= Gem::Version.new("6.0"))
    end

    #: () -> bool
    def self.mtest?
      return @mtest if defined?(@mtest)

      spec = Gem.loaded_specs["maxitest"]
      @mtest = !minitest_cli? && spec.is_a?(Gem::Specification) &&
               spec.version < Gem::Version.new("7.0")
    end

    #: () -> Integer
    def self.terminal_width
      if $stdout.tty?
        begin
          `tput cols`.strip.to_i
        rescue StandardError
          80
        end
      else
        80
      end
    end
  end
end
