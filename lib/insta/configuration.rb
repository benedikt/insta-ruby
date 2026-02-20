# frozen_string_literal: true

module Insta
  class Configuration
    # @rbs!
    #   type snapshot_filename_resolver =
    #     ^(test_name: String, counter: Integer, options: Hash[Symbol, untyped]) -> String

    attr_accessor :snapshot_path #: String
    attr_accessor :diff_display #: Symbol
    attr_accessor :diff_width #: Integer?
    attr_accessor :diff_color #: Symbol
    attr_accessor :update_mode #: Symbol
    attr_accessor :default_serializer #: Symbol
    attr_accessor :heredoc_identifier #: String
    attr_accessor :ci_mode #: Symbol
    attr_accessor :snapshot_extension #: String
    attr_accessor :snapshot_sanitizer #: (^(String) -> String)?
    attr_accessor :snapshot_filename #: snapshot_filename_resolver?
    attr_accessor :snapshot_directory #: (^(test_class: String) -> String)?
    attr_accessor :new_snapshot #: Symbol

    #: () -> void
    def initialize
      @snapshot_path = "test/snapshots"
      @diff_display = :side_by_side
      @diff_width = nil
      @diff_color = :auto
      @update_mode = :auto
      @default_serializer = :to_s
      @heredoc_identifier = "SNAP"
      @ci_mode = :auto
      @snapshot_extension = ".snap"
      @snapshot_sanitizer = nil
      @snapshot_filename = nil
      @snapshot_directory = nil
      @new_snapshot = :review
    end

    #: () -> Symbol
    def resolved_update_mode
      if ENV["INSTA_UPDATE"]
        case ENV.fetch("INSTA_UPDATE", nil)
        when "always", "force" then :force
        when "new" then :new
        when "no" then :no
        else :auto
        end
      elsif ENV["INSTA_FORCE_PASS"]
        :pending
      elsif resolved_ci_mode?
        :no
      else
        @update_mode
      end
    end

    #: () -> bool
    def resolved_ci_mode?
      case @ci_mode
      when :auto then CI.ci?
      when true then true
      else false
      end
    end

    #: () -> String
    def resolved_diff_color
      return "never" if ENV.key?("NO_COLOR")

      case @diff_color
      when :always then "always"
      when :never then "never"
      when :auto
        $stdout.tty? ? "always" : "never"
      else
        "auto"
      end
    end

    #: () -> String
    def resolved_diff_display
      case @diff_display
      when :inline then "inline"
      else "side-by-side-show-both"
      end
    end
  end
end
