# frozen_string_literal: true

require "test_helper"
require "open3"
require "rbconfig"

# Runs in a fresh Ruby, because the classes behave differently once this
# process has built an instance of them.
class TestAllocation < Minitest::Test
  LIB = File.expand_path("../lib", __dir__)
  NATIVE_CLASSES = %w[
    Store NamedNode BlankNode Literal Triple Query Update QuerySolutions QuerySolution QueryTriples
  ].freeze

  def test_no_native_class_allocates_an_object_without_its_data
    output, = Open3.capture2e(RbConfig.ruby, "-I", LIB, "-e", <<~'RUBY', *NATIVE_CLASSES)
      require "oxigraph"

      ARGV.each do |name|
        Oxigraph.const_get(name).allocate
        puts "#{name}: allocated"
      rescue TypeError
        puts "#{name}: TypeError"
      end
    RUBY

    assert_equal NATIVE_CLASSES.map { |name| "#{name}: TypeError" }, output.lines(chomp: true)
  end
end
