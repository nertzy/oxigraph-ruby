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

desc "Lint the workflows and the Dependabot configuration"
task(:jactionlint) { sh "jactionlint" }

desc "Lint Markdown"
task(:markdownlint) { sh %(npx --yes markdownlint-cli2@0.24.1 "**/*.md") }

desc "Run every linter"
task lint: %i[standard cargo:fmt cargo:clippy jactionlint markdownlint]

namespace :lint do
  desc "Apply the fixes every linter can make"
  task fix: "standard:fix" do
    # Clippy first: its fixes can leave code that rustfmt reformats. The flags
    # let it edit a checkout that has uncommitted changes.
    sh "cargo clippy --fix --allow-dirty --allow-staged --all-targets"
    sh "cargo fmt --all"
    sh "jactionlint --fix"
    sh %(npx --yes markdownlint-cli2@0.24.1 --fix "**/*.md")
  end
end

task default: %i[compile test lint]
