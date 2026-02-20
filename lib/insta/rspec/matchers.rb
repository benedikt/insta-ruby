# frozen_string_literal: true

require "rspec/expectations"

module Insta
  module RSpec
    module Matchers
      class MatchSnapshot
        include ::RSpec::Matchers::Composable

        attr_reader :failure_message #: String?

        #: (String?) -> void
        def initialize(name = nil)
          @name = name
          @failure_message = nil
        end

        #: (untyped) -> bool
        def matches?(actual)
          @actual = actual

          serializer_name = Insta.configuration.default_serializer
          serialized = Serializers.serialize(serializer_name, actual)
          content = SnapshotContent.normalize(serialized)

          example = ::RSpec.current_example
          return record_failure("Could not determine current RSpec example") unless example

          test_class = example.example_group.description || "Anonymous"
          test_method = example.description || "unknown"

          snapshot_file = resolve_snapshot_file(example, test_class, test_method)
          path = @name ? snapshot_file.named_path(@name) : snapshot_file.path_for

          metadata = { "source" => "#{test_class} #{test_method}" }
          existing = snapshot_file.read(path)

          return handle_new_snapshot(snapshot_file, path, content, metadata) unless existing

          expected = SnapshotContent.normalize(existing.content)
          return true if content == expected

          caller_line = example.location
          handle_mismatch(snapshot_file, path, content, metadata, expected, "#{test_class} #{test_method}", caller_line)
        end

        #: () -> String
        def description
          @name ? "match snapshot \"#{@name}\"" : "match snapshot"
        end

        private

        #: (untyped, String, String) -> SnapshotFile
        def resolve_snapshot_file(example, test_class, test_method)
          if @name
            SnapshotFile.new(Insta.configuration.snapshot_path, test_class, test_method)
          else
            example.metadata[:_insta_snapshot_file] ||= SnapshotFile.new(
              Insta.configuration.snapshot_path,
              test_class,
              test_method
            )
          end
        end

        #: (SnapshotFile, Pathname, String, Snapshot::snapshot_metadata) -> bool
        def handle_new_snapshot(snapshot_file, path, content, metadata)
          if Insta.configuration.resolved_update_mode == :no
            return record_failure("Snapshot file does not exist: #{path}\nRun with INSTA_UPDATE=force to create it.")
          end

          if Insta.configuration.new_snapshot == :review
            pending_path = snapshot_file.pending_path(path)
            snapshot_file.write(pending_path, content, metadata)

            example = ::RSpec.current_example
            caller_line = example&.location
            PendingLocations.add(pending_path.to_s, caller_line) if caller_line

            return true if ENV["INSTA_FORCE_PASS"]

            return record_failure("New snapshot pending review: #{path}\nRun `bundle exec insta review` to accept.")

          end

          snapshot_file.write(path, content, metadata)

          true
        end

        #: (SnapshotFile, Pathname, String, Snapshot::snapshot_metadata, String, String, String?) -> bool
        def handle_mismatch(snapshot_file, path, content, metadata, expected, label, caller_line = nil)
          result = SnapshotMismatchHandler.handle(snapshot_file, path, content, metadata, expected,
                                                  caller_line: caller_line)

          case result
          when :updated, :force_passed
            true
          else
            @failure_message = SnapshotMismatchHandler.failure_message(expected, content, label, path,
                                                                       caller_line: caller_line)

            false
          end
        end

        #: (String) -> false
        def record_failure(msg)
          @failure_message = msg

          false
        end
      end

      class MatchInlineSnapshot
        include ::RSpec::Matchers::Composable

        attr_reader :failure_message #: String?

        #: (String?) -> void
        def initialize(expected = nil)
          @expected = expected
          @failure_message = nil
        end

        #: (untyped) -> bool
        def matches?(actual)
          @actual = actual

          serializer_name = Insta.configuration.default_serializer
          serialized = Serializers.serialize(serializer_name, actual)
          content = SnapshotContent.normalize(serialized)

          location = (caller_locations || []).find { |location| location.path && !location.path.include?("lib/insta") && !location.path.include?("lib/rspec") }
          return record_failure("Could not determine caller location") unless location

          file = location.path
          line = location.lineno

          return record_failure("Could not determine source file") unless file
          return handle_new_inline_snapshot(file, line, content) if @expected.nil?

          expected_normalized = SnapshotContent.normalize(@expected.to_s)
          return true if content == expected_normalized

          handle_inline_mismatch(file, line, content, expected_normalized)
        end

        #: () -> String
        def description
          "match inline snapshot"
        end

        private

        #: (String, Integer, String) -> bool
        def handle_new_inline_snapshot(file, line, content)
          if Insta.configuration.new_snapshot == :review
            Inline::PendingStore.add(file: file, line: line, content: content, old_content: "", type: :insert)

            return true if ENV["INSTA_FORCE_PASS"]

            return record_failure("New inline snapshot pending review at #{file}:#{line}\nRun `bundle exec insta review` to accept.")
          end

          Inline::PendingRegistry.add(file: file, line: line, content: content, type: :insert)

          true
        end

        #: (String, Integer, String, String) -> bool
        def handle_inline_mismatch(file, line, content, expected_normalized)
          mode = Insta.configuration.resolved_update_mode

          case mode
          when :force
            Inline::PendingRegistry.add(file: file, line: line, content: content, type: :replace)

            true
          when :no
            @failure_message = Diff.failure_message(expected_normalized, content, "inline snapshot at #{file}:#{line}")

            false
          else
            Inline::PendingStore.add(file: file, line: line, content: content, old_content: expected_normalized,
                                     type: :replace)

            if ENV["INSTA_FORCE_PASS"]
              true
            else
              @failure_message = Diff.failure_message(expected_normalized, content,
                                                      "inline snapshot at #{file}:#{line}")

              false
            end
          end
        end

        #: (String) -> false
        def record_failure(msg)
          @failure_message = msg

          false
        end
      end

      #: (?String?) -> MatchSnapshot
      def match_snapshot(name = nil)
        MatchSnapshot.new(name)
      end

      #: (?String?) -> MatchInlineSnapshot
      def match_inline_snapshot(expected = nil)
        MatchInlineSnapshot.new(expected)
      end
    end
  end
end
