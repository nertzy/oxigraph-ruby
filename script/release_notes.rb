# frozen_string_literal: true

# Prints one version's section of the changelog, which is that version's
# release notes. Fails when the section is missing or has no entries.
#
#   ruby script/release_notes.rb 0.1.0

version, changelog = ARGV
abort "usage: ruby script/release_notes.rb <version> [changelog]" unless version
changelog ||= File.expand_path("../CHANGELOG.md", __dir__)

heading = "## [#{version}]"
section = File.read(changelog).split(/^(?=## )/).find do |text|
  text.start_with?("#{heading}\n", "#{heading} - ")
end

abort "No changelog section found for #{version}." unless section
# A category heading such as "### Added" is not an entry.
entries = section.lines.drop(1).reject { |line| line.strip.empty? || line.start_with?("#") }
abort "Changelog section for #{version} is empty." if entries.empty?

puts section.rstrip
