# frozen_string_literal: true

# Installs the one precompiled gem in a directory and uses it, to prove that
# it works with nothing but Ruby. The release workflow runs this on every
# platform it builds a gem for.
#
#   PLATFORM=aarch64-linux ruby script/verify_native_gem.rb pkg
#
# Set EXPECT_NO_COMPILER where the machine is meant to have no toolchain, so
# that a gem which compiled its extension could not have passed.

require "open3"

COMPILERS = %w[cargo rustc cc gcc clang make].freeze

USE_THE_GEM = <<~'RUBY'
  require "oxigraph"

  spec = Gem::Specification.find_by_name("oxigraph")
  expected = ENV.fetch("PLATFORM")
  abort "installed the #{spec.platform} gem, not the #{expected} one" unless spec.platform.to_s == expected

  minor = RUBY_VERSION[/\A\d+\.\d+/]
  unless $LOADED_FEATURES.any? { |feature| feature.include?("/oxigraph/#{minor}/oxigraph.") }
    abort "the extension did not load from the directory for Ruby #{minor}"
  end

  store = Oxigraph::Store.new
  store.load("<http://example.com/a> <http://example.com/p> <http://example.com/b> .", format: :n_triples)
  query = Oxigraph::Query.parse("SELECT ?o WHERE { <http://example.com/a> ?p ?o }")
  objects = store.query(query).map { |solution| solution[:o].to_s }
  abort "the query returned #{objects.inspect}" unless objects == ["<http://example.com/b>"]

  puts "oxigraph #{Oxigraph::VERSION} (#{spec.platform}) loaded on Ruby #{RUBY_VERSION}"
RUBY

gems = Dir[File.join(ARGV.fetch(0), "*.gem")]
abort "expected one gem in #{ARGV.fetch(0)}, found #{gems.size}" unless gems.one?

if ENV["EXPECT_NO_COMPILER"]
  directories = ENV.fetch("PATH").split(File::PATH_SEPARATOR)
  found = COMPILERS.select { |name| directories.any? { |directory| File.executable?(File.join(directory, name)) } }
  abort "#{found.join(", ")} installed, so this run would prove nothing" if found.any?
end

output, status = Open3.capture2e(Gem.ruby, "-S", "gem", "install", "--local", "--no-document", gems.first)
puts output
abort "gem install failed" unless status.success?
if output.include?("Building native extensions")
  abort "the gem compiled its extension instead of using the precompiled one"
end

exit 1 unless system(Gem.ruby, "-e", USE_THE_GEM)
