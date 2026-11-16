# frozen_string_literal: true

require "test_helper"

class TestNamedNode < Minitest::Test
  def test_reads_its_iri
    assert_equal "http://example.com/a", Oxigraph::NamedNode.new("http://example.com/a").value
  end

  def test_converts_to_n_triples
    assert_equal "<http://example.com/a>", Oxigraph::NamedNode.new("http://example.com/a").to_s
  end

  def test_inspects_readably
    assert_equal "#<Oxigraph::NamedNode <http://example.com/a>>", Oxigraph::NamedNode.new("http://example.com/a").inspect
  end

  def test_equals_a_node_with_the_same_iri
    node = Oxigraph::NamedNode.new("http://example.com/a")
    same = Oxigraph::NamedNode.new("http://example.com/a")

    assert_equal node, same
    assert node.eql?(same)
    assert_equal node.hash, same.hash
  end

  def test_differs_from_a_node_with_another_iri
    node = Oxigraph::NamedNode.new("http://example.com/a")
    other = Oxigraph::NamedNode.new("http://example.com/b")

    refute_equal node, other
    refute node.eql?(other)
  end

  def test_differs_from_its_iri_as_a_string
    refute_equal Oxigraph::NamedNode.new("http://example.com/a"), "http://example.com/a"
  end

  def test_works_as_a_hash_key
    labels = {Oxigraph::NamedNode.new("http://example.com/a") => "a"}

    assert_equal "a", labels[Oxigraph::NamedNode.new("http://example.com/a")]
    assert_nil labels[Oxigraph::NamedNode.new("http://example.com/b")]
  end

  def test_is_frozen
    assert_predicate Oxigraph::NamedNode.new("http://example.com/a"), :frozen?
  end

  def test_copies_are_the_same_object
    node = Oxigraph::NamedNode.new("http://example.com/a")

    assert_same node, node.dup
    assert_same node, node.clone
  end

  def test_copying_takes_the_arguments_copying_an_integer_takes
    node = Oxigraph::NamedNode.new("http://example.com/a")

    assert_same node, node.clone(freeze: true)
    assert_same node, node.clone(freeze: nil)
    assert_raises(ArgumentError) { node.dup(1) }
    assert_raises(ArgumentError) { node.clone(1) }
    assert_raises(ArgumentError) { node.clone(shallow: true) }
    assert_raises(ArgumentError) { node.clone(freeze: 1) }
  end

  def test_refuses_an_unfrozen_copy
    node = Oxigraph::NamedNode.new("http://example.com/a")

    error = assert_raises(ArgumentError) { node.clone(freeze: false) }

    assert_equal "can't unfreeze #{node.class}", error.message
  end

  def test_rejects_an_invalid_iri
    error = assert_raises(ArgumentError) { Oxigraph::NamedNode.new("http://example.com/a b") }

    assert_match(/IRI/i, error.message)
  end

  def test_rejects_a_relative_iri
    assert_raises(ArgumentError) { Oxigraph::NamedNode.new("a") }
  end

  def test_rejects_a_value_that_is_not_a_string
    assert_raises(TypeError) { Oxigraph::NamedNode.new(1) }
  end
end
