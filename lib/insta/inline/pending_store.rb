# frozen_string_literal: true

require "json"
require "fileutils"

module Insta
  module Inline
    # @rbs!
    #   type pending_store_entry = { file: String, line: Integer, content: String, old_content: String, type: String }

    module PendingStore
      FILENAME = ".insta-pending-inline"

      @pending = [] #: Array[Inline::pending_store_entry]
      @mutex = Mutex.new

      #: (file: String, line: Integer, content: String, old_content: String, type: Symbol) -> void
      def self.add(file:, line:, content:, old_content:, type:)
        @mutex.synchronize do
          @pending << {
            file: file,
            line: line,
            content: content,
            old_content: old_content,
            type: type.to_s,
          }
        end
      end

      #: () -> void
      def self.flush!
        entries = @mutex.synchronize do
          result = @pending.dup
          @pending.clear

          result
        end

        return if entries.empty?

        manifest_path = File.join(Insta.configuration.snapshot_path, FILENAME)
        existing = if File.exist?(manifest_path)
                     JSON.parse(File.read(manifest_path), symbolize_names: true)
                   else
                     [] #: Array[Inline::pending_store_entry]
                   end

        merged = merge_entries(existing, entries)

        FileUtils.mkdir_p(File.dirname(manifest_path))
        File.write(manifest_path, JSON.pretty_generate(merged))
      end

      #: () -> Array[Inline::pending_store_entry]
      def self.load
        manifest_path = File.join(Insta.configuration.snapshot_path, FILENAME)
        return [] unless File.exist?(manifest_path)

        JSON.parse(File.read(manifest_path), symbolize_names: true)
      rescue JSON::ParserError
        []
      end

      #: () -> void
      def self.clean!
        manifest_path = File.join(Insta.configuration.snapshot_path, FILENAME)

        FileUtils.rm_f(manifest_path)
      end

      #: (Array[Inline::pending_store_entry]) -> void
      def self.apply!(entries)
        grouped = entries.group_by { |entry| entry[:file] }

        grouped.each do |file, file_entries|
          next unless File.exist?(file)

          pending = file_entries.map { |entry|
            { line: entry[:line], content: entry[:content], type: entry[:type].to_sym }
          } #: Array[Inline::pending_entry]

          patched = FilePatcher.patch(file, pending)

          FilePatcher.atomic_write(file, patched)
        end
      end

      #: (Array[Inline::pending_store_entry]) -> void
      def self.remove!(entries)
        current = self.load
        return if current.empty?

        remaining = current.reject { |existing|
          entries.any? { |entry|
            existing[:file] == entry[:file] && existing[:line] == entry[:line]
          }
        }

        manifest_path = File.join(Insta.configuration.snapshot_path, FILENAME)

        if remaining.empty?
          FileUtils.rm_f(manifest_path)
        else
          File.write(manifest_path, JSON.pretty_generate(remaining))
        end
      end

      #: () -> bool
      def self.any?
        @mutex.synchronize { !@pending.empty? }
      end

      #: () -> Integer
      def self.size
        @mutex.synchronize { @pending.length }
      end

      #: () -> void
      def self.clear!
        @mutex.synchronize { @pending.clear }
      end

      #: (Array[Inline::pending_store_entry], Array[Inline::pending_store_entry]) -> Array[Inline::pending_store_entry]
      def self.merge_entries(existing, new_entries)
        result = existing.dup

        new_entries.each do |entry|
          index = result.index { |e|
            e[:file] == entry[:file] && e[:line] == entry[:line]
          }

          if index
            result[index] = entry
          else
            result << entry
          end
        end

        result
      end

      private_class_method :merge_entries
    end
  end
end
