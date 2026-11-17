# frozen_string_literal: true

require "test_helper"
require "open3"
require "rbconfig"
require "tempfile"

class TestReleaseNotes < Minitest::Test
  SCRIPT = File.expand_path("../script/release_notes.rb", __dir__)

  CHANGELOG = <<~MARKDOWN
    # Changelog

    ## [Unreleased]

    ## [0.2.0] - 2026-02-03

    ### Added

    - Added a second thing.

    ### Fixed

    - Fixed the first thing.

    ## [0.1.1] - 2026-01-10

    ### Added

    ### Fixed

    ## [0.1.0] - 2026-01-02

    ### Added

    - Added the first thing.
  MARKDOWN

  def test_prints_the_section_for_a_version
    output, status = release_notes("0.2.0")

    assert_predicate status, :success?
    assert_equal <<~MARKDOWN, output
      ## [0.2.0] - 2026-02-03

      ### Added

      - Added a second thing.

      ### Fixed

      - Fixed the first thing.
    MARKDOWN
  end

  def test_prints_the_last_section
    output, status = release_notes("0.1.0")

    assert_predicate status, :success?
    assert_equal "## [0.1.0] - 2026-01-02\n\n### Added\n\n- Added the first thing.\n", output
  end

  def test_fails_for_a_version_with_no_section
    output, status = release_notes("0.3.0")

    refute_predicate status, :success?
    assert_equal "No changelog section found for 0.3.0.\n", output
  end

  def test_does_not_match_a_version_by_its_prefix
    _, status = release_notes("0.1")

    refute_predicate status, :success?
  end

  def test_fails_for_an_empty_section
    output, status = release_notes("Unreleased")

    refute_predicate status, :success?
    assert_equal "Changelog section for Unreleased is empty.\n", output
  end

  def test_fails_for_a_section_with_headings_and_no_entries
    output, status = release_notes("0.1.1")

    refute_predicate status, :success?
    assert_equal "Changelog section for 0.1.1 is empty.\n", output
  end

  def test_reads_the_changelog_of_this_repository_by_default
    output, status = Open3.capture2e(RbConfig.ruby, SCRIPT, "0.0.0")

    refute_predicate status, :success?
    assert_equal "No changelog section found for 0.0.0.\n", output
  end

  private

  def release_notes(version)
    Tempfile.create(["CHANGELOG", ".md"]) do |changelog|
      changelog.write(CHANGELOG)
      changelog.flush
      Open3.capture2e(RbConfig.ruby, SCRIPT, version, changelog.path)
    end
  end
end
