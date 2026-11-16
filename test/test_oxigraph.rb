# frozen_string_literal: true

require "test_helper"

class TestOxigraph < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Oxigraph::VERSION
  end

  def test_hello_world
    assert_equal "Hello world, from Rust!", Oxigraph.hello("world")
  end
end
