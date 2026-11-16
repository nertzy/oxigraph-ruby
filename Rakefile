# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create

require "standard/rake"

require "rb_sys/extensiontask"

task build: :compile

GEMSPEC = Gem::Specification.load("oxigraph.gemspec")

RbSys::ExtensionTask.new("oxigraph", GEMSPEC) do |ext|
  ext.lib_dir = "lib/oxigraph"
end

namespace :cargo do
  desc "Check Rust formatting"
  task(:fmt) { sh "cargo fmt --all --check" }

  desc "Lint Rust with Clippy"
  task(:clippy) { sh "cargo clippy --all-targets -- -D warnings" }
end

task default: %i[compile test standard cargo:fmt cargo:clippy]
