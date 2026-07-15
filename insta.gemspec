# frozen_string_literal: true

require_relative "lib/insta/version"

Gem::Specification.new do |spec|
  spec.name = "insta"
  spec.version = Insta::VERSION
  spec.authors = ["Marco Roth"]
  spec.email = ["marco.roth@intergga.ch"]
  spec.homepage = "https://github.com/marcoroth/insta"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.summary = "Snapshot testing for Ruby"
  spec.description = <<~DESCRIPTION
    Snapshot testing for Ruby with inline snapshots, difftastic diffs, and interactive review. Supports Minitest and RSpec.
  DESCRIPTION

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/marcoroth/insta"
  spec.metadata["changelog_uri"] = "https://github.com/marcoroth/insta/releases"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    Dir["{lib,sig,exe}/**/*", "LICENSE.txt", "Rakefile"]
  end

  spec.bindir = "exe"
  spec.executables = ["insta"]
  spec.require_paths = ["lib"]

  spec.add_dependency "difftastic", ">= 0.2"
  spec.add_dependency "irb", "~> 1.0"
  spec.add_dependency "prism", ">= 1.0"
end
