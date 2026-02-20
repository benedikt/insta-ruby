# frozen_string_literal: true

module Insta
  module SnapshotMismatchHandler
    # Returns :updated, :force_passed, or :failed
    #: (SnapshotFile, Pathname, String, Snapshot::snapshot_metadata, String, ?caller_line: String?) -> Symbol
    def self.handle(snapshot_file, path, content, metadata, expected, caller_line: nil)
      coordinator = UpdateCoordinator.new(Insta.configuration.resolved_update_mode)
      decision = coordinator.resolve(expected, content)

      case decision
      when :update
        snapshot_file.write(path, content, metadata)
        :updated
      when :pending
        pending_path = snapshot_file.pending_path(path)
        snapshot_file.write(pending_path, content, metadata)
        PendingLocations.add(pending_path.to_s, caller_line) if caller_line

        ENV["INSTA_FORCE_PASS"] ? :force_passed : :failed
      else
        :failed
      end
    end

    #: (String, String, String, Pathname, ?caller_line: String?) -> String
    def self.failure_message(expected, content, label, path, caller_line: nil)
      Diff.failure_message(
        expected, content, label, path.to_s, caller_line,
        file_extension: File.extname(path.to_s).delete_prefix(".")
      )
    end
  end
end
