# frozen_string_literal: true

require "test_helper"

class TestUpdate < Minitest::Test
  UPDATES = [
    "INSERT DATA { <http://example.com/a> <http://example.com/p> <http://example.com/b> }",
    "DELETE DATA { <http://example.com/a> <http://example.com/p> <http://example.com/b> }",
    "DELETE WHERE { ?s ?p ?o }",
    "LOAD <http://example.com/data.ttl>",
    "DROP ALL"
  ].freeze

  def test_recognizes_an_update
    UPDATES.each do |update|
      assert_instance_of Oxigraph::Update, Oxigraph::Update.parse(update), update
    end
  end

  def test_converts_back_to_sparql
    update = Oxigraph::Update.parse("INSERT DATA { <http://example.com/a> <http://example.com/p> <http://example.com/b> }")

    assert_match(/INSERT DATA/, update.to_s)
    assert_equal update.to_s, Oxigraph::Update.parse(update.to_s).to_s
  end

  def test_inspects_readably
    assert_equal "#<Oxigraph::Update DROP ALL ;>", Oxigraph::Update.parse("DROP ALL").inspect
  end

  def test_is_frozen
    assert_predicate Oxigraph::Update.parse("DROP ALL"), :frozen?
  end

  def test_takes_predeclared_prefixes_and_a_base_iri
    update = Oxigraph::Update.parse(
      "INSERT DATA { ex:a ex:p <b> }",
      prefixes: {"ex" => "http://example.com/"}, base_iri: "http://example.org/"
    )

    assert_includes update.to_s, "<http://example.com/a>"
    assert_includes update.to_s, "<http://example.org/b>"
  end

  def test_rejects_a_query
    assert_raises(Oxigraph::QuerySyntaxError) { Oxigraph::Update.parse("SELECT * WHERE { ?s ?p ?o }") }
  end

  def test_rejects_text_that_is_not_sparql
    error = assert_raises(Oxigraph::QuerySyntaxError) { Oxigraph::Update.parse("INSERT DATA { oops") }

    assert_match(/\Aerror at 1:\d+: /, error.message)
  end

  def test_cannot_be_run
    refute_respond_to Oxigraph::Update.parse("DROP ALL"), :execute
    refute_respond_to Oxigraph::Store.new, :update
  end

  def test_is_built_only_by_parsing
    assert_raises(TypeError) { Oxigraph::Update.new }
    assert_raises(TypeError) { Oxigraph::Update.allocate }
  end

  def test_reports_the_line_and_column_of_a_syntax_error
    error = assert_raises(Oxigraph::QuerySyntaxError) { Oxigraph::Update.parse("INSERT DATA {\n <http://e/a> }") }

    assert_equal [2, 15], [error.line, error.column]
  end

  def test_reports_no_position_for_an_error_that_has_none
    update = "INSERT DATA { _:b <http://e/p> <http://e/o> } ; INSERT DATA { _:b <http://e/p> <http://e/q> }"
    error = assert_raises(Oxigraph::QuerySyntaxError) { Oxigraph::Update.parse(update) }

    assert_equal [nil, nil], [error.line, error.column]
  end
end
