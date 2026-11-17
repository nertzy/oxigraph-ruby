# frozen_string_literal: true

require "test_helper"

class TestTriple < Minitest::Test
  def setup
    @subject = Oxigraph::NamedNode.new("http://example.com/a")
    @predicate = Oxigraph::NamedNode.new("http://example.com/p")
    @object = Oxigraph::Literal.new("chat", language: "fr")
  end

  def test_reads_its_terms
    triple = Oxigraph::Triple.new(@subject, @predicate, @object)

    assert_equal @subject, triple.subject
    assert_equal @predicate, triple.predicate
    assert_equal @object, triple.object
  end

  def test_takes_a_blank_node_as_subject_or_object
    blank = Oxigraph::BlankNode.new("b0")
    triple = Oxigraph::Triple.new(blank, @predicate, blank)

    assert_equal blank, triple.subject
    assert_equal blank, triple.object
  end

  def test_takes_a_named_node_as_object
    assert_equal @subject, Oxigraph::Triple.new(@subject, @predicate, @subject).object
  end

  def test_converts_to_n_triples
    triple = Oxigraph::Triple.new(@subject, @predicate, @object)

    assert_equal '<http://example.com/a> <http://example.com/p> "chat"@fr', triple.to_s
  end

  def test_inspects_readably
    triple = Oxigraph::Triple.new(@subject, @predicate, @object)

    assert_equal '#<Oxigraph::Triple <http://example.com/a> <http://example.com/p> "chat"@fr>', triple.inspect
  end

  def test_equals_a_triple_with_the_same_terms
    triple = Oxigraph::Triple.new(@subject, @predicate, @object)
    same = Oxigraph::Triple.new(@subject, @predicate, Oxigraph::Literal.new("chat", language: "fr"))

    assert_equal triple, same
    assert triple.eql?(same)
    assert_equal triple.hash, same.hash
  end

  def test_differs_when_a_term_differs
    triple = Oxigraph::Triple.new(@subject, @predicate, @object)

    refute_equal triple, Oxigraph::Triple.new(@subject, @predicate, Oxigraph::Literal.new("chat"))
  end

  def test_works_as_a_hash_key
    seen = {Oxigraph::Triple.new(@subject, @predicate, @object) => true}

    assert seen[Oxigraph::Triple.new(@subject, @predicate, @object)]
  end

  def test_is_frozen
    assert_predicate Oxigraph::Triple.new(@subject, @predicate, @object), :frozen?
  end

  def test_copies_are_the_same_object
    triple = Oxigraph::Triple.new(@subject, @predicate, @object)

    assert_same triple, triple.dup
    assert_same triple, triple.clone
  end

  def test_copying_takes_the_arguments_copying_an_integer_takes
    triple = Oxigraph::Triple.new(@subject, @predicate, @object)

    assert_same triple, triple.clone(freeze: true)
    assert_same triple, triple.clone(freeze: nil)
    assert_raises(ArgumentError) { triple.dup(1) }
    assert_raises(ArgumentError) { triple.clone(1) }
    assert_raises(ArgumentError) { triple.clone(shallow: true) }
    assert_raises(ArgumentError) { triple.clone(freeze: 1) }
  end

  def test_refuses_an_unfrozen_copy
    triple = Oxigraph::Triple.new(@subject, @predicate, @object)

    error = assert_raises(ArgumentError) { triple.clone(freeze: false) }

    assert_equal "can't unfreeze #{triple.class}", error.message
  end

  def test_rejects_a_literal_subject
    assert_raises(TypeError) { Oxigraph::Triple.new(@object, @predicate, @object) }
  end

  def test_rejects_a_blank_node_predicate
    assert_raises(TypeError) { Oxigraph::Triple.new(@subject, Oxigraph::BlankNode.new("b0"), @object) }
  end

  def test_rejects_an_object_that_is_not_a_term
    assert_raises(TypeError) { Oxigraph::Triple.new(@subject, @predicate, "chat") }
  end
end
