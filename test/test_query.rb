# frozen_string_literal: true

require "test_helper"

class TestQuery < Minitest::Test
  WHERE_WITH_SERVICE = {
    "plain" => "{ SERVICE <http://example.com/sparql> { ?s ?p ?o } }",
    "silent" => "{ SERVICE SILENT <http://example.com/sparql> { ?s ?p ?o } }",
    "named by a variable" => "{ ?s ?p ?endpoint SERVICE ?endpoint { ?s ?p ?o } }",
    "in a group" => "{ ?s ?p ?o { SERVICE <http://example.com/sparql> { ?s ?p ?o } } }",
    "in OPTIONAL" => "{ ?s ?p ?o OPTIONAL { SERVICE <http://example.com/sparql> { ?s ?q ?x } } }",
    "in UNION" => "{ { ?s ?p ?o } UNION { SERVICE <http://example.com/sparql> { ?s ?p ?o } } }",
    "in MINUS" => "{ ?s ?p ?o MINUS { SERVICE <http://example.com/sparql> { ?s ?p ?o } } }",
    "in GRAPH" => "{ GRAPH ?g { SERVICE <http://example.com/sparql> { ?s ?p ?o } } }",
    "in a subquery" => "{ { SELECT ?s WHERE { SERVICE <http://example.com/sparql> { ?s ?p ?o } } } }",
    "in FILTER EXISTS" => "{ ?s ?p ?o FILTER EXISTS { SERVICE <http://example.com/sparql> { ?s ?p ?o } } }",
    "in FILTER NOT EXISTS" => "{ ?s ?p ?o FILTER NOT EXISTS { SERVICE SILENT <http://example.com/sparql> { ?s ?p ?o } } }",
    "in an OPTIONAL filter" => "{ ?s ?p ?o OPTIONAL { ?s ?q ?x FILTER(EXISTS { SERVICE <http://example.com/sparql> { ?s ?p ?o } }) } }",
    "in BIND" => "{ ?s ?p ?o BIND(EXISTS { SERVICE <http://example.com/sparql> { ?s ?p ?o } } AS ?found) }",
    "in a function argument" => "{ ?s ?p ?o FILTER(IF(EXISTS { SERVICE <http://example.com/sparql> { ?s ?p ?o } }, true, false)) }",
    "in an IN list" => "{ ?s ?p ?o FILTER(true IN (false, EXISTS { SERVICE <http://example.com/sparql> { ?s ?p ?o } })) }",
    "in a nested EXISTS" => "{ ?s ?p ?o FILTER EXISTS { ?s ?p ?o FILTER NOT EXISTS { SERVICE <http://example.com/sparql> { ?s ?p ?o } } } }"
  }.freeze

  def test_reports_the_form_of_a_query
    assert_equal :select, Oxigraph::Query.parse("SELECT * WHERE { ?s ?p ?o }").form
    assert_equal :ask, Oxigraph::Query.parse("ASK { ?s ?p ?o }").form
    assert_equal :construct, Oxigraph::Query.parse("CONSTRUCT { ?s ?p ?o } WHERE { ?s ?p ?o }").form
    assert_equal :describe, Oxigraph::Query.parse("DESCRIBE <http://example.com/a>").form
  end

  def test_a_query_without_service_has_none
    refute_predicate Oxigraph::Query.parse("SELECT * WHERE { ?s ?p ?o }"), :service?
  end

  WHERE_WITH_SERVICE.each do |place, where|
    define_method(:"test_finds_service_#{place.tr(" ", "_")}") do
      assert_predicate Oxigraph::Query.parse("SELECT * WHERE #{where}"), :service?
    end
  end

  def test_finds_service_in_every_query_form
    where = WHERE_WITH_SERVICE.fetch("plain")

    assert_predicate Oxigraph::Query.parse("ASK #{where}"), :service?
    assert_predicate Oxigraph::Query.parse("CONSTRUCT { ?s ?p ?o } WHERE #{where}"), :service?
    assert_predicate Oxigraph::Query.parse("DESCRIBE ?s WHERE #{where}"), :service?
  end

  def test_finds_service_in_order_by
    query = "SELECT * WHERE { ?s ?p ?o } ORDER BY (EXISTS { SERVICE <http://example.com/sparql> { ?s ?p ?o } })"

    assert_predicate Oxigraph::Query.parse(query), :service?
  end

  def test_finds_service_in_having
    query = "SELECT ?s WHERE { ?s ?p ?o } GROUP BY ?s HAVING (EXISTS { SERVICE <http://example.com/sparql> { ?s ?p ?o } })"

    assert_predicate Oxigraph::Query.parse(query), :service?
  end

  def test_finds_service_in_an_aggregate
    query = "SELECT (MAX(EXISTS { SERVICE <http://example.com/sparql> { ?s ?p ?o } }) AS ?found) WHERE { ?s ?p ?o }"

    assert_predicate Oxigraph::Query.parse(query), :service?
  end

  def test_the_word_service_in_a_string_or_an_iri_is_not_a_service_clause
    query = Oxigraph::Query.parse('SELECT * WHERE { ?s <http://example.com/SERVICE> "SERVICE" }')

    refute_predicate query, :service?
  end

  def test_reports_a_dataset_clause
    assert_predicate Oxigraph::Query.parse("SELECT * FROM <http://example.com/g> WHERE { ?s ?p ?o }"), :dataset?
    assert_predicate Oxigraph::Query.parse("SELECT * FROM NAMED <http://example.com/g> WHERE { ?s ?p ?o }"), :dataset?
    assert_predicate Oxigraph::Query.parse("ASK FROM <http://example.com/g> { ?s ?p ?o }"), :dataset?
  end

  def test_a_query_without_a_dataset_clause_has_none
    refute_predicate Oxigraph::Query.parse("SELECT * WHERE { GRAPH <http://example.com/g> { ?s ?p ?o } }"), :dataset?
  end

  def test_converts_back_to_sparql_that_parses_to_the_same_query
    query = Oxigraph::Query.parse("SELECT ?s WHERE { ?s ?p ?o } ORDER BY ?s LIMIT 3")

    assert_match(/SELECT/, query.to_s)
    assert_equal query.to_s, Oxigraph::Query.parse(query.to_s).to_s
  end

  def test_inspects_readably
    assert_match(/\A#<Oxigraph::Query SELECT .*>\z/, Oxigraph::Query.parse("SELECT * WHERE { ?s ?p ?o }").inspect)
  end

  def test_is_frozen
    assert_predicate Oxigraph::Query.parse("ASK { ?s ?p ?o }"), :frozen?
  end

  def test_takes_predeclared_prefixes
    query = Oxigraph::Query.parse("SELECT * WHERE { ex:a ?p ?o }", prefixes: {"ex" => "http://example.com/"})

    assert_includes query.to_s, "<http://example.com/a>"
  end

  def test_takes_prefixes_named_by_symbols
    query = Oxigraph::Query.parse("SELECT * WHERE { ex:a ?p ?o }", prefixes: {ex: "http://example.com/"})

    assert_includes query.to_s, "<http://example.com/a>"
  end

  def test_a_prefix_in_the_query_overrides_a_predeclared_one
    query = Oxigraph::Query.parse(
      "PREFIX ex: <http://example.org/> SELECT * WHERE { ex:a ?p ?o }",
      prefixes: {"ex" => "http://example.com/"}
    )

    assert_includes query.to_s, "<http://example.org/a>"
  end

  def test_resolves_relative_iris_against_a_base_iri
    query = Oxigraph::Query.parse("SELECT * WHERE { <a> ?p ?o }", base_iri: "http://example.com/")

    assert_includes query.to_s, "<http://example.com/a>"
  end

  def test_raises_a_syntax_error_that_says_where
    error = assert_raises(Oxigraph::QuerySyntaxError) { Oxigraph::Query.parse("SELECT * WHERE {\n  ?s ?p\n}") }

    assert_kind_of Oxigraph::Error, error
    assert_match(/\Aerror at 3:\d+: /, error.message)
  end

  def test_rejects_an_undeclared_prefix
    assert_raises(Oxigraph::QuerySyntaxError) { Oxigraph::Query.parse("SELECT * WHERE { ex:a ?p ?o }") }
  end

  def test_rejects_every_kind_of_update
    updates = [
      "INSERT DATA { <http://example.com/a> <http://example.com/p> <http://example.com/b> }",
      "DELETE DATA { <http://example.com/a> <http://example.com/p> <http://example.com/b> }",
      "DELETE WHERE { ?s ?p ?o }",
      "INSERT { ?s ?p ?o } WHERE { ?s ?p ?o }",
      "LOAD <http://example.com/data.ttl>",
      "CLEAR ALL",
      "DROP ALL",
      "CREATE GRAPH <http://example.com/g>"
    ]

    updates.each do |update|
      assert_raises(Oxigraph::QuerySyntaxError, update) { Oxigraph::Query.parse(update) }
    end
  end

  def test_rejects_an_invalid_base_iri
    assert_raises(ArgumentError) { Oxigraph::Query.parse("ASK { ?s ?p ?o }", base_iri: "not an iri") }
  end

  def test_rejects_an_invalid_prefix_iri
    assert_raises(ArgumentError) { Oxigraph::Query.parse("ASK { ?s ?p ?o }", prefixes: {"ex" => "not an iri"}) }
  end

  def test_rejects_prefixes_that_are_not_a_hash
    assert_raises(TypeError) { Oxigraph::Query.parse("ASK { ?s ?p ?o }", prefixes: "ex") }
  end

  def test_rejects_a_query_that_is_not_a_string
    assert_raises(TypeError) { Oxigraph::Query.parse(42) }
  end

  def test_is_built_only_by_parsing
    assert_raises(TypeError) { Oxigraph::Query.new }
    assert_raises(TypeError) { Oxigraph::Query.allocate }
  end

  def test_reports_the_line_and_column_of_a_syntax_error
    error = assert_raises(Oxigraph::QuerySyntaxError) { Oxigraph::Query.parse("SELECT *\nWHERE {\n ?s ?p }") }

    assert_equal [3, 9], [error.line, error.column]
  end

  def test_counts_a_column_in_characters
    error = assert_raises(Oxigraph::QuerySyntaxError) { Oxigraph::Query.parse("SELECT * WHERE { <http://e/é> ?p }") }

    assert_equal [1, 34], [error.line, error.column]
  end

  def test_names_an_undeclared_prefix
    error = assert_raises(Oxigraph::QuerySyntaxError) { Oxigraph::Query.parse("SELECT * WHERE { ?s ?p ex:Thing }") }

    assert_equal 'error at 1:24: the prefix "ex:" is not declared', error.message
    assert_equal [1, 24], [error.line, error.column]
  end

  def test_names_an_undeclared_prefix_wherever_it_is_used
    queries = {
      "SELECT * WHERE { ex:a ?p ?o }" => "ex:",
      "SELECT * WHERE { ?s ex:p ?o }" => "ex:",
      "SELECT * WHERE { ?s ex:p/ex:q ?o }" => "ex:",
      %(SELECT * WHERE { ?s ?p "1"^^xsd:integer }) => "xsd:",
      "SELECT * WHERE { ?s ?p ?o FILTER(?o = ex:a) }" => "ex:",
      "SELECT * WHERE { ?s ?p :a }" => ":",
      "SELECT * WHERE { ?s ex:p ?o FILTER(?o < 18) }" => "ex:",
      "PREFIX a: <http://example.com/>\nSELECT * WHERE { a:x ?p b:y }" => "b:"
    }

    queries.each do |query, prefix|
      error = assert_raises(Oxigraph::QuerySyntaxError, query) { Oxigraph::Query.parse(query) }

      assert_equal %(the prefix "#{prefix}" is not declared), error.message.sub(/\Aerror at \d+:\d+: /, ""), query
    end
  end

  def test_blames_no_prefix_for_another_syntax_error
    queries = [
      "SELECT *\nWHERE {\n ?s ?p }",
      %(SELECT * WHERE { ?s ?p "ex:a" ),
      %(SELECT * WHERE { ?s ?p """a "quoted" ex:a""" ),
      "SELECT * WHERE { ?s ?p <urn:ex:a> ",
      "SELECT * WHERE { ?s ?p _:b ",
      "SELECT * WHERE { ?s ?p ?o FILTER(?s < ?o && ?o > ?s) ",
      "# ex:a\nSELECT * WHERE { ?s ?p ",
      "PREFIX ex: <http://example.com/>\nSELECT * WHERE { ex:a ex:p ",
      "prefix ex:<http://example.com/> SELECT * WHERE { ex:a ex:p "
    ]

    queries.each do |query|
      error = assert_raises(Oxigraph::QuerySyntaxError, query) { Oxigraph::Query.parse(query) }

      refute_match(/is not declared/, error.message, query)
    end
  end

  def test_blames_no_prefix_declared_by_argument
    error = assert_raises(Oxigraph::QuerySyntaxError) do
      Oxigraph::Query.parse("SELECT * WHERE { ex:a ex:p ", prefixes: {ex: "http://example.com/"})
    end

    refute_match(/is not declared/, error.message)
  end

  def test_keeps_the_error_the_parser_reached_before_an_undeclared_prefix
    error = assert_raises(Oxigraph::QuerySyntaxError) { Oxigraph::Query.parse("SELECT * WHERE { ?s ?p } ex:a") }

    refute_match(/is not declared/, error.message)
  end

  def test_keeps_the_parsers_error_after_a_less_than_sign_that_opens_no_iri
    queries = [
      "SELECT * WHERE { ?s ?p ?o FILTER(?s < ex:a) }",
      "SELECT * WHERE { ?s ?p ?o FILTER(?s<ex:a) }",
      "SELECT * WHERE { ?s ?p ?o FILTER(?o<18) . ?s ex:p ?o }",
      "SELECT * WHERE { ?s ?p ?o FILTER(?o<1e2) . ?s ex:p ?o }",
      "SELECT * WHERE { ?s ?p ?o FILTER(?o<1.8E-2) . ?s ex:p ?o }",
      "SELECT * WHERE { << ?s ?p ex:a >> ?q ?o }",
      "SELECT * WHERE { <<ex:a ?p ?o>> ?q ?r }",
      "SELECT * WHERE { <<<http://example.com/a> ?p ex:o>> ?q ?r }"
    ]

    queries.each do |query|
      error = assert_raises(Oxigraph::QuerySyntaxError, query) { Oxigraph::Query.parse(query) }

      refute_match(/is not declared/, error.message, query)
    end
  end

  def test_names_an_undeclared_prefix_that_another_error_follows
    error = assert_raises(Oxigraph::QuerySyntaxError) { Oxigraph::Query.parse("SELECT * WHERE { ?s ex:p ?o . ?s ?p }") }

    assert_equal 'error at 1:21: the prefix "ex:" is not declared', error.message
  end

  def test_blames_no_prefix_that_only_a_string_or_a_comment_holds
    queries = [
      "SELECT * WHERE { ?s ?p ?o FILTER(?a<'x>ex:p') ",
      "SELECT * WHERE { ?s ?p ?o FILTER(?a<?b)#a>b ex:p\n "
    ]

    queries.each do |query|
      error = assert_raises(Oxigraph::QuerySyntaxError, query) { Oxigraph::Query.parse(query) }

      refute_match(/is not declared/, error.message, query)
    end
  end

  def test_names_an_undeclared_prefix_in_unusual_text
    queries = {
      "SELECT * WHERE { # note\r ?s ?p ex:a }" => "ex:",
      "SELECT * WHERE { ?s ?p ?o FILTER(?o-ex:a > 1) }" => "ex:",
      "SELECT * WHERE { _:b.PREFIX ex:p ?o }" => "ex:",
      "SELECT * WHERE { ?s ?p e\u0301x:a }" => "e\u0301x:"
    }

    queries.each do |query, prefix|
      error = assert_raises(Oxigraph::QuerySyntaxError, query) { Oxigraph::Query.parse(query) }

      assert_equal %(the prefix "#{prefix}" is not declared), error.message.sub(/\Aerror at \d+:\d+: /, ""), query
    end
  end

  def test_blames_no_prefix_in_unusual_text
    queries = [
      "# note\rPREFIX ex: <http://example.com/>\nSELECT * WHERE { ex:a ex:p ",
      "PREFIX # note\n ex: <http://example.com/>\nSELECT * WHERE { ex:a ex:p ",
      "SELECT * WHERE { ?s ?p <urn:foo ",
      "SELECT * WHERE { ?s ?p <urn:foo ?o ex:a> ",
      "BASE <http://example.com/> SELECT * WHERE { ?s ?p <2026/ex:a",
      "SELECT * WHERE { ?s ?p ?o FILTER(?o<<http://example.com/a ) }",
      "SELECT * WHERE { ?s ?p ?o FILTER(?o<<http://example.com/a ) } # >>",
      "PREFIX e\u0301x: <http://example.com/>\nSELECT * WHERE { e\u0301x:a ?p ",
      "PREFIX ex: <http://example.com/>\nSELECT * WHERE { ex:a\u00B7b:c ?p ",
      "PREFIX ex: <http://example.com/>\nSELECT * WHERE { ?s ?p \"chat\"@fr-be ; ex:p "
    ]

    queries.each do |query|
      error = assert_raises(Oxigraph::QuerySyntaxError, query) { Oxigraph::Query.parse(query) }

      refute_match(/is not declared/, error.message, query)
    end
  end
end
