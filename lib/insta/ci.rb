# frozen_string_literal: true

module Insta
  module CI
    CI_ENV_VARS = [
      "CI",
      "GITHUB_ACTIONS",
      "CIRCLECI",
      "TRAVIS",
      "JENKINS_URL",
      "BUILDKITE",
      "GITLAB_CI",
      "TF_BUILD"
    ].freeze #: Array[String]

    #: () -> bool
    def self.ci?
      CI_ENV_VARS.any? { |var| ENV.key?(var) }
    end
  end
end
