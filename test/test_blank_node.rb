# frozen_string_literal: true

require "test_helper"

class TestBlankNode < Minitest::Test
  def test_reads_its_identifier
    assert_equal "b0", Oxigraph::BlankNode.new("b0").value
  end

  def test_converts_to_n_triples
    assert_equal "_:b0", Oxigraph::BlankNode.new("b0").to_s
  end

  def test_inspects_readably
    assert_equal "#<Oxigraph::BlankNode _:b0>", Oxigraph::BlankNode.new("b0").inspect
  end

  def test_generates_an_identifier_when_none_is_given
    refute_empty Oxigraph::BlankNode.new.value
  end

  def test_generates_a_different_identifier_each_time
    refute_equal Oxigraph::BlankNode.new, Oxigraph::BlankNode.new
  end

  def test_equals_a_node_with_the_same_identifier
    node = Oxigraph::BlankNode.new("b0")
    same = Oxigraph::BlankNode.new("b0")

    assert_equal node, same
    assert node.eql?(same)
    assert_equal node.hash, same.hash
  end

  def test_differs_from_a_node_with_another_identifier
    refute_equal Oxigraph::BlankNode.new("b0"), Oxigraph::BlankNode.new("b1")
  end

  def test_differs_from_a_named_node
    refute_equal Oxigraph::BlankNode.new("b0"), Oxigraph::NamedNode.new("http://example.com/b0")
  end

  def test_works_as_a_hash_key
    labels = {Oxigraph::BlankNode.new("b0") => "first"}

    assert_equal "first", labels[Oxigraph::BlankNode.new("b0")]
  end

  def test_is_frozen
    assert_predicate Oxigraph::BlankNode.new("b0"), :frozen?
  end

  def test_copies_are_the_same_object
    node = Oxigraph::BlankNode.new("b0")

    assert_same node, node.dup
    assert_same node, node.clone
  end

  def test_copying_takes_the_arguments_copying_an_integer_takes
    node = Oxigraph::BlankNode.new("b0")

    assert_same node, node.clone(freeze: true)
    assert_same node, node.clone(freeze: nil)
    assert_raises(ArgumentError) { node.dup(1) }
    assert_raises(ArgumentError) { node.clone(1) }
    assert_raises(ArgumentError) { node.clone(shallow: true) }
    assert_raises(ArgumentError) { node.clone(freeze: 1) }
  end

  def test_refuses_an_unfrozen_copy
    node = Oxigraph::BlankNode.new("b0")

    error = assert_raises(ArgumentError) { node.clone(freeze: false) }

    assert_equal "can't unfreeze #{node.class}", error.message
  end

  def test_rejects_an_invalid_identifier
    assert_raises(ArgumentError) { Oxigraph::BlankNode.new("not valid") }
  end

  def test_rejects_an_identifier_that_is_not_a_string
    assert_raises(TypeError) { Oxigraph::BlankNode.new(1) }
  end
end
