# frozen_string_literal: true

require "test_helper"

class TestStore < Minitest::Test
  def test_a_new_store_holds_no_quads
    store = Oxigraph::Store.new

    assert_equal 0, store.size
    assert_empty store
  end

  def test_stores_are_independent_objects
    refute_same Oxigraph::Store.new, Oxigraph::Store.new
  end
end
