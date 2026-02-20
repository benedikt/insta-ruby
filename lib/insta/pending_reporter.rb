# frozen_string_literal: true

module Insta
  module PendingReporter
    #: () -> void
    def self.flush_and_report!
      Inline::PendingRegistry.flush!
      Inline::PendingStore.flush!
      PendingLocations.flush!

      report_pending_files!
      report_pending_inline!
    end

    #: () -> void
    def self.report_pending_files!
      snapshot_path = Insta.configuration.snapshot_path
      extension = Insta.configuration.snapshot_extension
      pending_files = Dir.glob(File.join(snapshot_path, "**", "*#{extension}.new"))

      return unless pending_files.any?

      count = pending_files.length
      noun = count == 1 ? "snapshot" : "snapshots"
      warn "\n\e[33m●\e[0m #{count} pending file #{noun}:\n\n"
      pending_files.each { |f| warn "  \e[33m›\e[0m #{f}" }
      warn "\n  \e[36mbundle exec insta review\e[0m\n\n"
    end

    #: () -> void
    def self.report_pending_inline!
      entries = Inline::PendingStore.load
      return unless entries.any?

      count = entries.length
      noun = count == 1 ? "snapshot" : "snapshots"
      warn "\n\e[33m●\e[0m #{count} pending inline #{noun}:\n\n"

      entries.each do |entry|
        warn "  \e[33m›\e[0m #{entry[:file]}:#{entry[:line]}"
      end

      warn "\n  \e[36mbundle exec insta review\e[0m\n\n"
    end
  end
end
