# frozen_string_literal: true

require_relative "lib/oxigraph/version"

Gem::Specification.new do |spec|
  spec.name = "oxigraph"
  spec.version = Oxigraph::VERSION
  spec.authors = ["Grant Hutchins"]
  spec.email = ["gems@nertzy.com"]

  spec.summary = "Ruby bindings for Oxigraph, a SPARQL database and RDF toolkit."
  spec.description = spec.summary
  spec.homepage = "https://github.com/nertzy/oxigraph-ruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4"
  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # An explicit list, so the packaged gem does not depend on a Git checkout.
  # Cargo.toml and Cargo.lock at the root are the workspace the extension
  # builds in when the gem is installed from source.
  spec.files = Dir[
    "CHANGELOG.md", "Cargo.lock", "Cargo.toml", "LICENSE", "README.md",
    "ext/**/*.{rb,rs,toml}", "lib/**/*.rb"
  ]
  spec.require_paths = ["lib"]
  spec.extensions = ["ext/oxigraph/extconf.rb"]

  spec.add_dependency "rb_sys", ">= 0.9.128"
end
