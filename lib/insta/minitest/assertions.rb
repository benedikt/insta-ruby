# frozen_string_literal: true

module Insta
  module Minitest
    # @rbs module-self: Minitest::Test
    module Assertions
      #: (
      #|   untyped,
      #|   ?name: String?,
      #|   ?serializer: Symbol?,
      #|   ?redact: Hash[String, untyped]?,
      #|   ?input: String?,
      #|   ?description: String?,
      #|   ?info: Hash[String, untyped]?,
      #|   ?options: Hash[Symbol, untyped]?
      #| ) -> void
      def assert_snapshot(actual, name: nil, serializer: nil, redact: nil, input: nil, description: nil, info: nil, options: nil)
        expression = actual.class.name
        serializer_name = serializer || Insta.configuration.default_serializer
        actual = Redaction::Applicator.apply(actual, redact) if redact
        serialized = Serializers.serialize(serializer_name, actual)
        content = SnapshotContent.normalize(serialized)

        test_class = self.class.name || "Anonymous"
        test_method = self.name || "unknown"

        path = if name
                 snapshot_file = SnapshotFile.new(
                   Insta.configuration.snapshot_path,
                   test_class,
                   test_method
                 )
                 snapshot_file.named_path(name)
               else
                 snapshot_file = _insta_snapshot_file
                 snapshot_file.path_for(options || {})
               end

        metadata = build_metadata(
          test_class,
          test_method,
          expression: expression,
          input: input,
          description: description,
          info: info,
          options: options
        )

        existing = snapshot_file.read(path)

        unless existing
          handle_missing_snapshot(snapshot_file, path, content, metadata)
          return
        end

        if existing.expression && existing.expression != expression
          caller_line = find_test_caller
          handle_type_mismatch(snapshot_file, path, content, metadata, existing, expression, caller_line)
          return
        end

        expected = SnapshotContent.normalize(existing.content)

        if content == expected
          pass
          return
        end

        caller_line = find_test_caller
        handle_snapshot_mismatch(snapshot_file, path, content, metadata, expected, test_class, test_method, caller_line)
      end

      #: (
      #|   untyped,
      #|   ?String?,
      #|   ?serializer: Symbol?,
      #|   ?redact: Hash[String, untyped]?
      #| ) -> void
      def assert_inline_snapshot(actual, expected = nil, serializer: nil, redact: nil)
        serializer_name = serializer || Insta.configuration.default_serializer
        actual = Redaction::Applicator.apply(actual, redact) if redact
        serialized = Serializers.serialize(serializer_name, actual)
        content = SnapshotContent.normalize(serialized)

        location = caller_locations(1, 1)&.first
        return flunk("Could not determine caller location") unless location

        file = location.path
        line = location.lineno

        return flunk("Could not determine source file") unless file

        if expected.nil?
          if Insta.configuration.new_snapshot == :review
            Inline::PendingStore.add(file: file, line: line, content: content, old_content: "", type: :insert)

            if ENV["INSTA_FORCE_PASS"]
              pass
            else
              flunk "New inline snapshot pending review at #{file}:#{line}\nRun `bundle exec insta review` to accept."
            end
          else
            Inline::PendingRegistry.add(file: file, line: line, content: content, type: :insert)
            pass
          end

          return
        end

        expected_normalized = SnapshotContent.normalize(expected.to_s)

        if content == expected_normalized
          pass
          return
        end

        handle_inline_mismatch(file, line, content, expected_normalized)
      end

      private

      #: () -> SnapshotFile
      def _insta_snapshot_file
        @_insta_snapshot_file ||= SnapshotFile.new(
          Insta.configuration.snapshot_path,
          self.class.name || "Anonymous",
          name || "unknown"
        )
      end

      #: () -> String
      def find_test_caller
        locations = caller_locations
        return locations&.first.to_s unless locations

        test_location = locations.find { |location|
          path = location.path

          path && !path.include?("lib/insta") && path.match?(/_test\.rb\z/)
        }

        (test_location || locations.first).to_s
      end

      #: (String, String, ?expression: String?, ?input: String?, ?description: String?,
      #|   ?info: Hash[String, untyped]?, ?options: Hash[Symbol, untyped]?) -> Snapshot::snapshot_metadata
      def build_metadata(test_class, test_method, expression: nil, input: nil, description: nil, info: nil, options: nil)
        metadata = { "source" => "#{test_class}##{test_method}" }

        metadata["expression"] = expression if expression
        metadata["input"] = input if input
        metadata["description"] = description if description
        metadata["options"] = options if options && !options.empty?
        metadata["info"] = info if info

        metadata
      end

      #: (SnapshotFile, Pathname, String, Snapshot::snapshot_metadata) -> void
      def handle_missing_snapshot(snapshot_file, path, content, metadata)
        mode = Insta.configuration.resolved_update_mode

        if mode == :no
          flunk "Snapshot file does not exist: #{path}\nRun with INSTA_UPDATE=force to create it."
          return
        end

        if Insta.configuration.new_snapshot == :review
          pending_path = snapshot_file.pending_path(path)
          snapshot_file.write(pending_path, content, metadata)
          PendingLocations.add(pending_path.to_s, find_test_caller)

          if ENV["INSTA_FORCE_PASS"]
            pass
          else
            flunk "New snapshot pending review: #{path}\nRun `bundle exec insta review` to accept."
          end

          return
        end

        snapshot_file.write(path, content, metadata)

        pass
      end

      #: (SnapshotFile, Pathname, String, Snapshot::snapshot_metadata, Snapshot, String?, String) -> void
      def handle_type_mismatch(snapshot_file, path, content, metadata, existing, expression, caller_line)
        expected = SnapshotContent.normalize(existing.content)
        result = SnapshotMismatchHandler.handle(snapshot_file, path, content, metadata, expected, caller_line: caller_line)

        case result
        when :updated, :force_passed
          pass
        else
          flunk "Snapshot type mismatch: snapshot was #{existing.expression} but got #{expression}\n" \
                "Run `bundle exec insta review` or delete the snapshot file and re-run the test to update it."
        end
      end

      #: (SnapshotFile, Pathname, String, Snapshot::snapshot_metadata, String, String, String, String) -> void
      def handle_snapshot_mismatch(snapshot_file, path, content, metadata, expected, test_class, test_method, caller_line)
        result = SnapshotMismatchHandler.handle(snapshot_file, path, content, metadata, expected, caller_line: caller_line)

        case result
        when :updated, :force_passed
          pass
        else
          label = "#{test_class}##{test_method}"
          flunk SnapshotMismatchHandler.failure_message(expected, content, label, path, caller_line: caller_line)
        end
      end

      #: (String, Integer, String, String) -> void
      def handle_inline_mismatch(file, line, content, expected_normalized)
        mode = Insta.configuration.resolved_update_mode

        case mode
        when :force
          Inline::PendingRegistry.add(file: file, line: line, content: content, type: :replace)
          pass
        when :no
          flunk Diff.failure_message(
            expected_normalized,
            content,
            "inline snapshot at #{file}:#{line}",
            nil,
            "#{file}:#{line}"
          )
        else # :auto, :pending
          Inline::PendingStore.add(
            file: file,
            line: line,
            content: content,
            old_content: expected_normalized,
            type: :replace
          )

          if ENV["INSTA_FORCE_PASS"]
            pass
          else
            flunk Diff.failure_message(
              expected_normalized,
              content,
              "inline snapshot at #{file}:#{line}",
              nil,
              "#{file}:#{line}"
            )
          end
        end
      end
    end
  end
end
