# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"

# Each test loads the gem in a fresh Ruby, because this process has already
# loaded the extension.
class TestExtensionLoading < Minitest::Test
  LIB = File.expand_path("../lib", __dir__)
  VERSIONED_EXTENSION = "oxigraph/#{RUBY_VERSION[/\A\d+\.\d+/]}/oxigraph.rb"

  def test_reports_the_error_of_a_versioned_extension_that_fails_to_load
    output = load_gem_beside_versioned_extension('raise LoadError, "the versioned extension is broken"')

    assert_equal ["LoadError: the versioned extension is broken", "Oxigraph::Store is not defined"], output
  end

  private

  # Puts a stand-in for the versioned extension ahead of `lib`, which holds
  # the extension that was compiled for this checkout.
  def load_gem_beside_versioned_extension(source)
    Dir.mktmpdir do |directory|
      stand_in = File.join(directory, VERSIONED_EXTENSION)
      FileUtils.mkdir_p(File.dirname(stand_in))
      File.write(stand_in, source)

      output, = Open3.capture2e(RbConfig.ruby, "-I", directory, "-I", LIB, "-e", <<~'RUBY')
        begin
          require "oxigraph"
        rescue LoadError => error
          puts "LoadError: #{error.message}"
        end
        puts "Oxigraph::Store is #{"not " unless defined?(Oxigraph::Store)}defined"
      RUBY
      output.lines(chomp: true)
    end
  end
end
