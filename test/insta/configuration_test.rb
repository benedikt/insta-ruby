# frozen_string_literal: true

require_relative "../test_helper"

class ConfigurationTest < Minitest::Spec
  test "default values" do
    config = Insta::Configuration.new

    assert_equal "test/snapshots", config.snapshot_path
    assert_equal :side_by_side, config.diff_display
    assert_nil config.diff_width
    assert_equal :auto, config.diff_color
    assert_equal :auto, config.update_mode
    assert_equal :to_s, config.default_serializer
    assert_equal "SNAP", config.heredoc_identifier
    assert_equal :auto, config.ci_mode
    assert_equal ".snap", config.snapshot_extension
    assert_nil config.snapshot_sanitizer
    assert_nil config.snapshot_filename
    assert_nil config.snapshot_directory
  end

  test "configure block" do
    Insta.configure do |config|
      config.snapshot_path = "spec/snapshots"
      config.diff_display = :inline
      config.heredoc_identifier = "SNAPSHOT"
    end

    assert_equal "spec/snapshots", Insta.configuration.snapshot_path
    assert_equal :inline, Insta.configuration.diff_display
    assert_equal "SNAPSHOT", Insta.configuration.heredoc_identifier
  end

  test "resolved update mode defaults to auto" do
    config = Insta::Configuration.new
    config.ci_mode = false

    assert_equal :auto, config.resolved_update_mode
  end

  test "resolved update mode with INSTA_UPDATE=force" do
    ENV["INSTA_UPDATE"] = "force"
    config = Insta::Configuration.new

    assert_equal :force, config.resolved_update_mode
  ensure
    ENV.delete("INSTA_UPDATE")
  end

  test "resolved update mode with INSTA_UPDATE=new" do
    ENV["INSTA_UPDATE"] = "new"
    config = Insta::Configuration.new

    assert_equal :new, config.resolved_update_mode
  ensure
    ENV.delete("INSTA_UPDATE")
  end

  test "resolved update mode with INSTA_UPDATE=always" do
    ENV["INSTA_UPDATE"] = "always"
    config = Insta::Configuration.new

    assert_equal :force, config.resolved_update_mode
  ensure
    ENV.delete("INSTA_UPDATE")
  end

  test "resolved update mode with INSTA_UPDATE=no" do
    ENV["INSTA_UPDATE"] = "no"
    config = Insta::Configuration.new

    assert_equal :no, config.resolved_update_mode
  ensure
    ENV.delete("INSTA_UPDATE")
  end

  test "resolved update mode with INSTA_FORCE_PASS" do
    ENV["INSTA_FORCE_PASS"] = "1"
    config = Insta::Configuration.new

    assert_equal :pending, config.resolved_update_mode
  ensure
    ENV.delete("INSTA_FORCE_PASS")
  end

  test "resolved diff display side by side" do
    config = Insta::Configuration.new
    config.diff_display = :side_by_side

    assert_equal "side-by-side-show-both", config.resolved_diff_display
  end

  test "resolved diff display inline" do
    config = Insta::Configuration.new
    config.diff_display = :inline

    assert_equal "inline", config.resolved_diff_display
  end

  test "reset configuration" do
    Insta.configure { |c| c.snapshot_path = "custom/path" }
    assert_equal "custom/path", Insta.configuration.snapshot_path

    Insta.reset_configuration!
    assert_equal "test/snapshots", Insta.configuration.snapshot_path
  end
end
