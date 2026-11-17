# frozen_string_literal: true

require "test_helper"

class TestStoreQuery < Minitest::Test
  PREFIXES = {
    "ex" => "http://example.com/",
    "rdfs" => "http://www.w3.org/2000/01/rdf-schema#"
  }.freeze

  DATA = <<~TURTLE
    @prefix ex: <http://example.com/> .
    @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
    ex:a rdfs:subClassOf ex:b ; rdfs:label "chat"@fr, "cat"@en ; ex:rank 1 .
    ex:b rdfs:subClassOf ex:c ; rdfs:label "beast" ; ex:rank 2 .
    ex:c ex:seeAlso [ rdfs:label "anonymous" ] .
  TURTLE

  def setup
    @store = Oxigraph::Store.new
    @store.load(DATA, format: :turtle)
  end

  def test_follows_a_property_path
    solutions = select("SELECT ?x WHERE { ex:a rdfs:subClassOf+ ?x } ORDER BY ?x")

    assert_equal [node("b"), node("c")], solutions.map { |solution| solution[:x] }
  end

  def test_takes_a_query_as_a_string
    query = "SELECT ?x WHERE { <http://example.com/a> <http://www.w3.org/2000/01/rdf-schema#subClassOf> ?x }"

    assert_equal [node("b")], @store.query(query).map { |solution| solution[:x] }
  end

  def test_names_the_variables_of_a_select
    assert_equal %i[s label], select("SELECT ?s ?label WHERE { ?s rdfs:label ?label }").variables
  end

  def test_reads_a_binding_by_symbol_string_or_position
    solution = select("SELECT ?x ?rank WHERE { ?x ex:rank ?rank } ORDER BY ?rank").first

    assert_equal node("a"), solution[:x]
    assert_equal node("a"), solution["x"]
    assert_equal node("a"), solution[0]
    assert_equal "1", solution[1].value
  end

  def test_an_unbound_variable_is_nil
    query = "SELECT ?x ?parent WHERE { ?x ex:seeAlso ?other OPTIONAL { ?x rdfs:subClassOf ?parent } }"
    solution = select(query).first

    assert_equal node("c"), solution[:x]
    assert_nil solution[:parent]
    assert_nil solution[1]
  end

  def test_a_position_past_the_end_is_nil
    assert_nil select("SELECT ?x WHERE { ex:a rdfs:subClassOf ?x }").first[1]
  end

  def test_a_variable_the_query_does_not_select_raises
    solution = select("SELECT ?x WHERE { ex:a rdfs:subClassOf ?x }").first

    error = assert_raises(IndexError) { solution[:y] }

    assert_match(/y/, error.message)
  end

  def test_a_binding_key_of_another_type_raises
    solution = select("SELECT ?x WHERE { ex:a rdfs:subClassOf ?x }").first

    assert_raises(TypeError) { solution[1.5] }
  end

  def test_converts_a_solution_to_a_hash
    query = "SELECT ?x ?parent WHERE { ?x ex:seeAlso ?other OPTIONAL { ?x rdfs:subClassOf ?parent } }"

    assert_equal({x: node("c"), parent: nil}, select(query).first.to_h)
  end

  def test_inspects_a_solution_readably
    solution = select("SELECT ?x WHERE { ex:a rdfs:subClassOf ?x }").first

    assert_equal "#<Oxigraph::QuerySolution x=<http://example.com/b>>", solution.inspect
  end

  def test_tells_the_kinds_of_term_apart
    named = select("SELECT ?o WHERE { ex:a rdfs:subClassOf ?o }").first[:o]
    blank = select("SELECT ?o WHERE { ex:c ex:seeAlso ?o }").first[:o]
    literal = select('SELECT ?o WHERE { ex:a rdfs:label ?o FILTER(LANG(?o) = "fr") }').first[:o]
    integer = select("SELECT ?o WHERE { ex:a ex:rank ?o }").first[:o]

    assert_instance_of Oxigraph::NamedNode, named
    assert_instance_of Oxigraph::BlankNode, blank
    assert_equal Oxigraph::Literal.new("chat", language: "fr"), literal
    assert_equal "http://www.w3.org/2001/XMLSchema#integer", integer.datatype.value
    assert_equal "1", integer.value
  end

  def test_yields_solutions_to_a_block
    seen = []

    select("SELECT ?x WHERE { ex:a rdfs:subClassOf+ ?x } ORDER BY ?x").each { |solution| seen << solution[:x] }

    assert_equal [node("b"), node("c")], seen
  end

  def test_returns_an_enumerator_without_a_block
    enumerator = select("SELECT ?x WHERE { ex:a rdfs:subClassOf+ ?x } ORDER BY ?x").each

    assert_instance_of Enumerator, enumerator
    assert_equal node("b"), enumerator.next[:x]
    assert_equal node("c"), enumerator.next[:x]
    assert_raises(StopIteration) { enumerator.next }
  end

  def test_results_are_enumerable
    solutions = select("SELECT ?x WHERE { ?x ex:rank ?rank } ORDER BY DESC(?rank)")

    assert_kind_of Enumerable, solutions
    assert_equal [node("b")], solutions.first(1).map { |solution| solution[:x] }
  end

  def test_results_can_be_read_only_once
    solutions = select("SELECT ?x WHERE { ex:a rdfs:subClassOf+ ?x }")
    solutions.to_a

    error = assert_raises(Oxigraph::Error) { solutions.to_a }

    assert_match(/once/, error.message)
  end

  def test_results_stopped_early_cannot_be_restarted
    solutions = select("SELECT ?x WHERE { ex:a rdfs:subClassOf+ ?x }")
    solutions.first

    assert_raises(Oxigraph::Error) { solutions.first }
  end

  def test_results_do_not_change_when_the_store_does
    solutions = select("SELECT ?x WHERE { ex:a rdfs:subClassOf+ ?x }")
    @store.load("<http://example.com/c> <http://www.w3.org/2000/01/rdf-schema#subClassOf> <http://example.com/d> .", format: :n_triples)

    assert_equal 2, solutions.count
  end

  def test_answers_an_ask
    assert_same true, @store.query("ASK { <http://example.com/a> ?p ?o }")
    assert_same false, @store.query("ASK { <http://example.com/z> ?p ?o }")
  end

  def test_constructs_triples
    triples = select("CONSTRUCT { ?child ex:under ?parent } WHERE { ?child rdfs:subClassOf ?parent }")

    assert_instance_of Oxigraph::QueryTriples, triples
    assert_equal(
      [Oxigraph::Triple.new(node("a"), node("under"), node("b")), Oxigraph::Triple.new(node("b"), node("under"), node("c"))],
      triples.sort_by(&:to_s)
    )
  end

  def test_triples_stream_like_solutions
    triples = select("CONSTRUCT { ?child ex:under ?parent } WHERE { ?child rdfs:subClassOf ?parent }")

    assert_instance_of Enumerator, triples.each
    assert_kind_of Enumerable, triples
    assert_equal 2, triples.count
    assert_raises(Oxigraph::Error) { triples.to_a }
  end

  def test_describes_a_resource
    triples = select("DESCRIBE ex:b").to_a

    assert_equal 3, triples.size
    assert(triples.all? { |triple| triple.subject == node("b") })
  end

  def test_evaluates_optional_union_filter_distinct_and_count
    assert_equal ["beast", "cat"], values(<<~SPARQL)
      SELECT DISTINCT ?label WHERE {
        { ?s rdfs:label ?label FILTER(CONTAINS(STR(?label), "a") && REGEX(?label, "^[bc]") && LANG(?label) != "fr") }
        UNION
        { ?s ex:missing ?label }
        OPTIONAL { ?s ex:rank ?rank }
      } ORDER BY ?label
    SPARQL
    assert_equal ["4"], values("SELECT (COUNT(?label) AS ?count) WHERE { ?s rdfs:label ?label }")
    assert_equal ["c"], values("SELECT ?name WHERE { ex:a rdfs:subClassOf/rdfs:subClassOf ?x BIND(STRAFTER(STR(?x), 'http://example.com/') AS ?name) }")
    assert_equal 3, select("SELECT ?x WHERE { ex:a rdfs:subClassOf* ?x }").count
  end

  def test_never_runs_an_update
    update = "INSERT DATA { <http://example.com/x> <http://example.com/p> <http://example.com/y> }"

    assert_raises(Oxigraph::QuerySyntaxError) { @store.query(update) }
    assert_raises(Oxigraph::QuerySyntaxError) { @store.query("DROP ALL") }
    assert_raises(TypeError) { @store.query(Oxigraph::Update.parse(update)) }
    assert_equal 9, @store.size
  end

  def test_refuses_service
    error = assert_raises(Oxigraph::UnsupportedError) do
      @store.query("SELECT * WHERE { SERVICE <http://example.com/sparql> { ?s ?p ?o } }")
    end

    assert_kind_of Oxigraph::Error, error
    assert_match(/SERVICE/, error.message)
  end

  def test_refuses_a_silent_service_instead_of_answering_with_nothing
    assert_raises(Oxigraph::UnsupportedError) do
      @store.query("SELECT * WHERE { SERVICE SILENT <http://example.com/sparql> { ?s ?p ?o } }")
    end
  end

  def test_refuses_service_in_a_parsed_query_and_in_an_ask
    query = Oxigraph::Query.parse("ASK { ?s ?p ?o FILTER NOT EXISTS { SERVICE SILENT <http://example.com/sparql> { ?s ?p ?o } } }")

    assert_raises(Oxigraph::UnsupportedError) { @store.query(query) }
  end

  def test_evaluates_a_dataset_clause_against_the_graphs_in_the_store
    @store.load("<http://example.com/n> <http://example.com/p> <http://example.com/o> <http://example.com/g> .", format: :n_quads)

    assert_equal [node("n")], @store.query("SELECT ?s FROM <http://example.com/g> WHERE { ?s ?p ?o }").map { |solution| solution[:s] }
    assert_empty @store.query("SELECT ?s FROM <http://example.com/absent> WHERE { ?s ?p ?o }").to_a
    assert_equal 0, @store.query("SELECT ?s WHERE { ?s <http://example.com/p> ?o }").count
  end

  def test_rejects_a_query_that_is_neither_a_string_nor_a_query
    assert_raises(TypeError) { @store.query(42) }
  end

  def test_results_are_built_only_by_a_query
    [Oxigraph::QuerySolutions, Oxigraph::QuerySolution, Oxigraph::QueryTriples].each do |results|
      assert_raises(TypeError) { results.new }
      assert_raises(TypeError) { results.allocate }
    end
  end

  def test_reports_the_line_and_column_of_a_syntax_error_in_a_string
    error = assert_raises(Oxigraph::QuerySyntaxError) { Oxigraph::Store.new.query("SELECT *\nWHERE {\n ?s ?p }") }

    assert_equal [3, 9], [error.line, error.column]
  end

  def test_names_an_undeclared_prefix_in_a_string
    error = assert_raises(Oxigraph::QuerySyntaxError) { Oxigraph::Store.new.query("ASK { ?s ?p ex:a }") }

    assert_equal 'error at 1:13: the prefix "ex:" is not declared', error.message
  end

  private

  def select(sparql) = @store.query(Oxigraph::Query.parse(sparql, prefixes: PREFIXES))

  def values(sparql) = select(sparql).map { |solution| solution[0].value }

  def node(name) = Oxigraph::NamedNode.new("http://example.com/#{name}")
end
