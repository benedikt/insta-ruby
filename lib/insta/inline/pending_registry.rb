# frozen_string_literal: true

module Insta
  module Inline
    module PendingRegistry
      @pending = {} #: Hash[String, Array[Inline::pending_entry]]
      @mutex = Mutex.new

      #: (file: String, line: Integer, content: String, type: Symbol) -> void
      def self.add(file:, line:, content:, type:)
        @mutex.synchronize do
          @pending[file] = @pending[file] || [] #: Array[Inline::pending_entry]
          @pending[file] << { line: line, content: content, type: type }
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

        entries.each do |file, pending_entries|
          unless File.exist?(file)
            warn "insta: skipping inline snapshot update for missing file: #{file}"

            next
          end

          patched = FilePatcher.patch(file, pending_entries)

          FilePatcher.atomic_write(file, patched)
        end
      end

      #: () -> bool
      def self.any?
        @mutex.synchronize { !@pending.empty? }
      end

      #: () -> Integer
      def self.size
        @mutex.synchronize { @pending.values.sum(&:length) }
      end

      #: () -> void
      def self.clear!
        @mutex.synchronize { @pending.clear }
      end
    end
  end
end
