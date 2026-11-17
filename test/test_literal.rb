# frozen_string_literal: true

require "test_helper"

class TestLiteral < Minitest::Test
  XSD_STRING = "http://www.w3.org/2001/XMLSchema#string"
  XSD_INTEGER = "http://www.w3.org/2001/XMLSchema#integer"
  RDF_LANG_STRING = "http://www.w3.org/1999/02/22-rdf-syntax-ns#langString"

  def test_reads_its_lexical_form
    assert_equal "chat", Oxigraph::Literal.new("chat").value
  end

  def test_is_a_string_without_a_datatype_or_language
    literal = Oxigraph::Literal.new("chat")

    assert_equal Oxigraph::NamedNode.new(XSD_STRING), literal.datatype
    assert_nil literal.language
    assert_equal '"chat"', literal.to_s
  end

  def test_carries_a_language_tag
    literal = Oxigraph::Literal.new("chat", language: "fr")

    assert_equal "fr", literal.language
    assert_equal Oxigraph::NamedNode.new(RDF_LANG_STRING), literal.datatype
    assert_equal '"chat"@fr', literal.to_s
  end

  def test_carries_a_datatype
    literal = Oxigraph::Literal.new("1", datatype: Oxigraph::NamedNode.new(XSD_INTEGER))

    assert_equal Oxigraph::NamedNode.new(XSD_INTEGER), literal.datatype
    assert_nil literal.language
    assert_equal "\"1\"^^<#{XSD_INTEGER}>", literal.to_s
  end

  def test_escapes_its_lexical_form_in_n_triples
    assert_equal '"say \"hi\"\n"', Oxigraph::Literal.new("say \"hi\"\n").to_s
  end

  def test_inspects_readably
    assert_equal '#<Oxigraph::Literal "chat"@fr>', Oxigraph::Literal.new("chat", language: "fr").inspect
  end

  def test_equals_a_literal_with_the_same_parts
    literal = Oxigraph::Literal.new("chat", language: "fr")
    same = Oxigraph::Literal.new("chat", language: "fr")

    assert_equal literal, same
    assert literal.eql?(same)
    assert_equal literal.hash, same.hash
  end

  def test_equals_the_same_string_typed_explicitly
    assert_equal Oxigraph::Literal.new("chat"), Oxigraph::Literal.new("chat", datatype: Oxigraph::NamedNode.new(XSD_STRING))
  end

  def test_differs_by_language
    refute_equal Oxigraph::Literal.new("chat", language: "fr"), Oxigraph::Literal.new("chat", language: "en")
    refute_equal Oxigraph::Literal.new("chat", language: "fr"), Oxigraph::Literal.new("chat")
  end

  def test_differs_by_datatype
    refute_equal Oxigraph::Literal.new("1", datatype: Oxigraph::NamedNode.new(XSD_INTEGER)), Oxigraph::Literal.new("1")
  end

  def test_compares_lexical_forms_not_values
    integer = Oxigraph::NamedNode.new(XSD_INTEGER)

    refute_equal Oxigraph::Literal.new("1", datatype: integer), Oxigraph::Literal.new("01", datatype: integer)
  end

  def test_differs_from_its_lexical_form_as_a_string
    refute_equal Oxigraph::Literal.new("chat"), "chat"
  end

  def test_works_as_a_hash_key
    counts = {Oxigraph::Literal.new("chat", language: "fr") => 1}

    assert_equal 1, counts[Oxigraph::Literal.new("chat", language: "fr")]
    assert_nil counts[Oxigraph::Literal.new("chat")]
  end

  def test_is_frozen
    assert_predicate Oxigraph::Literal.new("chat"), :frozen?
  end

  def test_copies_are_the_same_object
    literal = Oxigraph::Literal.new("chat")

    assert_same literal, literal.dup
    assert_same literal, literal.clone
  end

  def test_copying_takes_the_arguments_copying_an_integer_takes
    literal = Oxigraph::Literal.new("chat")

    assert_same literal, literal.clone(freeze: true)
    assert_same literal, literal.clone(freeze: nil)
    assert_raises(ArgumentError) { literal.dup(1) }
    assert_raises(ArgumentError) { literal.clone(1) }
    assert_raises(ArgumentError) { literal.clone(shallow: true) }
    assert_raises(ArgumentError) { literal.clone(freeze: 1) }
  end

  def test_refuses_an_unfrozen_copy
    literal = Oxigraph::Literal.new("chat")

    error = assert_raises(ArgumentError) { literal.clone(freeze: false) }

    assert_equal "can't unfreeze #{literal.class}", error.message
  end

  def test_lowercases_a_language_tag
    assert_equal "en-us", Oxigraph::Literal.new("color", language: "en-US").language
  end

  def test_rejects_both_a_datatype_and_a_language
    assert_raises(ArgumentError) do
      Oxigraph::Literal.new("chat", datatype: Oxigraph::NamedNode.new(XSD_STRING), language: "fr")
    end
  end

  def test_rejects_an_invalid_language_tag
    assert_raises(ArgumentError) { Oxigraph::Literal.new("chat", language: "not a tag") }
  end

  def test_rejects_a_datatype_that_is_not_a_named_node
    assert_raises(TypeError) { Oxigraph::Literal.new("1", datatype: XSD_INTEGER) }
  end

  def test_rejects_a_lexical_form_that_is_not_a_string
    assert_raises(TypeError) { Oxigraph::Literal.new(1) }
  end

  def test_rejects_an_unknown_keyword
    assert_raises(ArgumentError) { Oxigraph::Literal.new("chat", lang: "fr") }
  end
end
