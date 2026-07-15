<div align="center">
  <img src="https://github.com/marcoroth/insta-ruby/blob/main/assets/insta.png?raw=true" width="250" height="250">

  <h4>Snapshot Testing for Ruby</h4>

  <p>Capture test output as snapshots and review changes interactively with difftastic-powered diffs.</p>

  <p>
    <a href="https://rubygems.org/gems/insta"><img alt="Gem Version" src="https://img.shields.io/gem/v/insta.svg"></a>
    <a href="https://github.com/marcoroth/insta-ruby/blob/main/LICENSE.txt"><img alt="License" src="https://img.shields.io/github/license/marcoroth/insta-ruby"></a>
  </p>
</div>

## Snapshot Testing

Snapshot tests assert values against a reference snapshot. Think of it as a supercharged version of `assert_equal` where the reference value is managed by Insta for you.

When the output changes, you get a diff and the option to review and accept the new value. This is particularly useful when the output is large, changes frequently, or is tedious to construct by hand.

Supports **Minitest** and **RSpec**. Ships with an interactive review CLI and [difftastic](https://github.com/marcoroth/difftastic-ruby)-powered diffs. Extracted from [Herb](https://github.com/marcoroth/herb), inspired by the [insta](https://insta.rs) crate for Rust and [Vitest snapshots](https://vitest.dev/guide/snapshot).

### When to reach for snapshots

Snapshots shine when you want to assert the whole thing without writing an assertion for every detail: full JSON API responses, rendered views and HTML, ASTs and compiled output, CLI output, error messages. See that it changed, see how, then accept or reject.

Insta is **not** a replacement for WebMock or VCR: those manage what goes *into* your code, Insta asserts what comes *out*. They compose well: a cassette pins the HTTP input while a snapshot reviews your code's output.

## Quick Start

Add to your Gemfile:

```ruby
gem "insta"
```

### Minitest

```ruby
require "insta/minitest"

class MyTest < Minitest::Test
  def test_output
    assert_snapshot(render_template)
  end
end
```

### RSpec

```ruby
require "insta/rspec"

RSpec.describe MyClass do
  it "renders correctly" do
    expect(render_template).to match_snapshot
  end
end
```

### The workflow

1. Write a test with `assert_snapshot` or `match_snapshot`
2. Run the test, it fails and creates a pending snapshot (`.snap.new`)
3. Review with `bundle exec insta review`
4. Accept, the snapshot is saved, the test passes on the next run
5. When the output changes, the test fails again with a diff. Repeat from step 3

Reviewing never re-runs your tests: pending snapshots are written at assertion time during the test run, so `insta review` and `insta accept` are pure file operations, instant even on a large suite. When one change touches many snapshots, that's one review session, not many hand-edits.

## Serializers and Multiple Snapshots

Snapshots aren't limited to strings. Pass a serializer to capture structured values, one snapshot where you'd otherwise write many assertions:

```ruby
def test_user_payload
  user = { id: 42, name: "Ada", roles: [:admin, :author], active: true }

  assert_snapshot(user, serializer: :yaml, name: "user_payload")
  assert_snapshot(user.keys, serializer: :json, name: "user_keys")
end
```

Available serializers: `:to_s` (default), `:inspect`, `:json`, `:yaml`. Use `name:` to keep multiple snapshots in a single test.

## Redactions

Volatile values like IDs and timestamps would make snapshots fail on every run. Redact them with jq-like selectors:

```ruby
assert_snapshot(
  user,
  serializer: :yaml,
  redact: {
    ".id" => "[id]",
    ".**.created_at" => "[timestamp]"
  }
)
```

The snapshot stores the placeholder instead of the volatile value:

```yaml
:id: "[id]"
:name: Ada
:created_at: "[timestamp]"
```

Supported selectors: `.key`, `["key"]`, `[index]`, `[]` (all array items), `.*` (all hash values), `.**` (deep). Redactions operate on structured data, so use `serializer: :json` or `:yaml`. For volatile values embedded in plain strings (like a timestamp interpolated into rendered output), freeze time in the test (`travel_to` / Timecop), which composes naturally with snapshots.

## Inline Snapshots

Inline snapshots store the expected value directly in the test file instead of a separate `.snap` file. (Minitest: `assert_inline_snapshot`, RSpec: `match_inline_snapshot`.)

### Writing your first inline snapshot

Start by writing the assertion without an expected value:

```ruby
def test_greeting
  assert_inline_snapshot(greet("world"))
end
```

Run the test, then review with `insta review`. Once accepted, Insta rewrites your source file:

```ruby
def test_greeting
  assert_inline_snapshot(greet("world"), "Hello, world!")
end
```

Multi-line values are written as heredocs automatically:

```ruby
def test_template
  assert_inline_snapshot(render_template, <<~SNAP)
    <div>
      Hello, world!
    </div>
  SNAP
end
```

### How updates work

When the expected value is **missing** (no expected value provided), the test fails and the pending snapshot is saved. You then review it with `insta review`, which shows the new value and lets you accept or reject. This is how you bootstrap a new inline snapshot.

When the expected value is **outdated** (doesn't match the actual value), the test fails the same way. You review the diff with `insta review` and accept to patch your source file, or reject to discard the change. This is the same workflow as file snapshots.

To skip the review step and update snapshots directly, run your tests with:

```bash
INSTA_UPDATE=force bundle exec rake test
```

## Metadata

Snapshots can carry metadata that appears in the YAML frontmatter of the `.snap` file:

```ruby
assert_snapshot(result, input: template, description: "Parsing test")
```

This produces a snapshot file like:

```yaml
---
source: "MyTest#test_output"
input: "<div>hello</div>"
description: "Parsing test"
---
Hello, world!
```

## Configuration

```ruby
Insta.configure do |config|
  config.snapshot_path = "test/snapshots"        # where snapshot files are stored
  config.snapshot_extension = ".snap"            # file extension for snapshots
  config.update_mode = :auto                     # :auto, :force, :no
  config.new_snapshot = :review                  # :review (require review), :auto (create and pass)
  config.diff_display = :side_by_side            # :side_by_side, :inline
  config.diff_width = nil                        # terminal width for diffs (nil = auto-detect)
  config.diff_color = :auto                      # :auto, :always, :never
  config.default_serializer = :to_s              # :to_s, :inspect, :json, :yaml
  config.heredoc_identifier = "SNAP"             # heredoc identifier for inline snapshots
  config.ci_mode = :auto                         # :auto, true, false (auto-detects CI environments)
  config.snapshot_sanitizer = nil                # optional Proc for custom filename sanitization
  config.snapshot_filename = nil                 # optional Proc for custom snapshot filenames
  config.snapshot_directory = nil                # optional Proc for custom snapshot directory per test class
end
```

### The `.insta.rb` config file

`Insta.configure` in your test helper only affects test runs. The review CLI is a separate process, so to share configuration between both, put it in `.insta.rb` at your project root:

```ruby
Insta.configure do |config|
  config.diff_display = :inline
end
```

Both the test integrations and `bundle exec insta` load this file automatically. Settings like `diff_display`, `diff_width`, and `snapshot_path` then apply everywhere, including `insta review`.

### Custom Filename Sanitization

By default, insta sanitizes snapshot filenames by replacing non-alphanumeric characters with underscores. You can provide a custom sanitizer:

```ruby
Insta.configure do |config|
  config.snapshot_sanitizer = ->(name) {
    name.gsub(" ", "_").gsub("/", "_")
  }
end
```

## CLI

The `insta` executable manages pending snapshots files:

```bash
insta status     # show snapshot overview and counts
insta review     # interactively review pending snapshots
insta accept     # accept all pending snapshots
insta reject     # reject all pending snapshots
insta pending    # list pending snapshots
insta clean      # remove pending snapshot files
```

## Environment Variables

| Variable                | Description                                         |
| ----------------------- | --------------------------------------------------- |
| `INSTA_UPDATE=always`   | Update snapshots in place, tests pass               |
| `INSTA_UPDATE=new`      | Accept only new snapshots, existing mismatches fail |
| `INSTA_UPDATE=no`       | No files written, fail on any mismatch              |
| `INSTA_FORCE_PASS=true` | Create `.snap.new` files without failing tests      |

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment. To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/marcoroth/insta. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/marcoroth/insta/blob/main/CODE_OF_CONDUCT.md).

## Code of Conduct

Everyone interacting in the Insta project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/marcoroth/insta/blob/main/CODE_OF_CONDUCT.md).

## Prior Art

Snapshot testing has a long lineage, and Insta stands on a lot of shoulders:

- Approval testing is the original form of the idea: capture a known-good output, compare against it, "approve" changes. [Approval Tests](https://approvaltests.com) formalized the pattern across many languages; in Ruby, the [approvals](https://rubygems.org/gems/approvals) gem carries this tradition.
- [Jest](https://jestjs.io/docs/snapshot-testing) popularized the term *snapshot testing* for the JavaScript world (auto-managed snapshot files, `toMatchSnapshot()`), and **[Vitest](https://vitest.dev/guide/snapshot)** refined it, including inline snapshots that rewrite your test file.
- [insta](https://insta.rs) (Armin Ronacher, Rust) added the piece the others were missing: a first-class interactive review workflow (`cargo insta review`) with pending snapshot files, redactions, and inline snapshots. Insta for Ruby takes its name, its flow, and its look and feel from it.
- In Ruby, [rspec-snapshot](https://rubygems.org/gems/rspec-snapshot) and [snapshot_testing](https://rubygems.org/gems/snapshot_testing) provide snapshot matchers for their respective frameworks.

What Insta adds to the Ruby ecosystem is the combination: framework-agnostic (Minitest *and* RSpec), the interactive review CLI as the center of the workflow (never re-running your tests), structural [difftastic](https://github.com/marcoroth/difftastic-ruby) diffs, inline snapshots rewritten via [Prism](https://github.com/ruby/prism), redaction selectors, and CI-aware update modes.

## Acknowledgments

Extracted from [herb](https://github.com/marcoroth/herb)'s snapshot test infrastructure, where a hand-rolled `SnapshotUtils` module proved the need across thousands of parser, lexer, and compiler tests.

The concept and the interactive review workflow are inspired by [insta](https://insta.rs), Armin Ronacher's snapshot testing library for Rust. Inline snapshot ergonomics are inspired by [Vitest](https://vitest.dev/guide/snapshot).

Diffing is powered by [difftastic](https://github.com/marcoroth/difftastic-ruby) and [pretty_please](https://github.com/joeldrapper/pretty_please), the same stack behind [minitest-difftastic](https://github.com/marcoroth/minitest-difftastic).

Thanks to [Renan Garcia](https://github.com/renan-garcia) for transferring the `insta` gem name. The previous gem is available at [`renan-garcia/insta`](https://github.com/renan-garcia/insta).

## License

The gem is available as open source under the terms of the [MIT License](https://github.com/marcoroth/insta/blob/main/LICENSE.txt).
