# frozen_string_literal: true

require_relative "insta/version"
require_relative "insta/ci"
require_relative "insta/configuration"
require_relative "insta/snapshot"
require_relative "insta/snapshot_content"
require_relative "insta/snapshot_name"
require_relative "insta/snapshot_file"
require_relative "insta/diff"
require_relative "insta/update_coordinator"
require_relative "insta/snapshot_mismatch_handler"
require_relative "insta/serializers/base"
require_relative "insta/serializers/string"
require_relative "insta/serializers/inspect"
require_relative "insta/serializers/json"
require_relative "insta/serializers/yaml"
require_relative "insta/inline/call_finder"
require_relative "insta/inline/edit"
require_relative "insta/inline/file_patcher"
require_relative "insta/inline/pending_registry"
require_relative "insta/inline/pending_store"
require_relative "insta/pending_locations"
require_relative "insta/pending_reporter"

module Insta
  #: () -> Configuration
  def self.configuration
    @configuration ||= Configuration.new
  end

  #: () { (Configuration) -> void } -> void
  def self.configure(&block)
    block.call(configuration)
  end

  #: () -> void
  def self.reset_configuration!
    @configuration = Configuration.new
  end
end
