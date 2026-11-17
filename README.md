# oxigraph-ruby

Ruby bindings for [Oxigraph](https://github.com/oxigraph/oxigraph), a SPARQL database and RDF toolkit. The gem is named `oxigraph` and wraps the Oxigraph Rust library in a native extension.

This is an unofficial binding and is not affiliated with the Oxigraph project.

## Install

The gem is not published to RubyGems yet. Build it from source by pointing Bundler at a commit of this repository:

```ruby
gem "oxigraph", git: "https://github.com/nertzy/oxigraph-ruby", ref: "<commit SHA>"
```

Building needs Ruby 3.4 or newer and a [Rust toolchain](https://rustup.rs) at version 1.87 or newer.

## Stores and queries

A store holds an RDF dataset in memory:

```ruby
require "oxigraph"

store = Oxigraph::Store.new
store.size   # => 0
store.empty? # => true
```

## Loading RDF

`Store#load` reads RDF from a string, from an `IO`, or from a file:

```ruby
store.load("<http://example.com/a> <http://example.com/p> <http://example.com/b> .", format: :n_triples)
File.open("more.ttl") { |io| store.load(io, format: :turtle) }
store.load(path: "vocabulary.ttl")
store.load(path: "ontology.owl", format: :rdf_xml, base_iri: "http://example.com/")
```

- The formats are `:turtle`, `:rdf_xml`, `:n_triples`, `:n_quads`, `:trig`, `:n3`, and `:json_ld`.
- `format:` is required with a string or an `IO`. With `path:` it defaults to the format the file extension names, and an extension that names none raises `ArgumentError`.
- Data goes to the default graph unless the format carries graph names.
- An `IO` is read in chunks, so a large file is never held in memory as one string. Any object with an `IO`-style `read(length)` works.
- A load is all or nothing. Malformed input raises `Oxigraph::ParseError` and leaves the store unchanged.
- Blank nodes are renamed on the way in, so a label from the input is not the identifier in the store.

`load` returns an `Oxigraph::LoadSummary`:

```ruby
summary = store.load("@prefix ex: <http://example.com/> . ex:a ex:p ex:b .", format: :turtle)
summary.prefixes # => {"ex" => "http://example.com/"}
summary.base_iri # => nil
```

`prefixes` holds what the input declared, in no particular order (sort it if the order matters), and `base_iri` is the base IRI in effect at its end. Turtle, TriG, and N3 report their prefixes. RDF/XML reports none: its `xmlns` declarations do not appear.

`Oxigraph::ParseError` has `line` and `column`, counted from one:

```ruby
begin
  store.load("<http://example.com/a> oops", format: :turtle)
rescue Oxigraph::ParseError => error
  error.message # => "Parser error at line 1 between columns 24 and 28: oops is not a valid predicate"
  error.line    # => 1
  error.column  # => 24
end
```

Both are `nil` when the parser reports no position, which is the case for RDF/XML.

## Querying

`Store#query` runs a SPARQL query, given as a string or as a parsed `Oxigraph::Query`:

```ruby
store = Oxigraph::Store.new
store.load(<<~TURTLE, format: :turtle)
  @prefix ex: <http://example.com/> .
  @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
  ex:a rdfs:subClassOf ex:b ; rdfs:label "chat"@fr .
  ex:b rdfs:subClassOf ex:c .
TURTLE

query = Oxigraph::Query.parse(
  "SELECT ?x WHERE { ex:a rdfs:subClassOf+ ?x } ORDER BY ?x",
  prefixes: {"ex" => "http://example.com/", "rdfs" => "http://www.w3.org/2000/01/rdf-schema#"}
)

solutions = store.query(query)
solutions.variables # => [:x]
solutions.each do |solution|
  solution[:x] # => #<Oxigraph::NamedNode <http://example.com/b>>, then <http://example.com/c>
end
```

What `query` returns depends on the form of the query:

| Form | Result |
| --- | --- |
| `SELECT` | `Oxigraph::QuerySolutions`, an `Enumerable` of `Oxigraph::QuerySolution` |
| `CONSTRUCT`, `DESCRIBE` | `Oxigraph::QueryTriples`, an `Enumerable` of `Oxigraph::Triple` |
| `ASK` | `true` or `false` |

- A solution is read with `solution[:x]`, `solution["x"]`, or `solution[0]`. An unbound variable reads as `nil`, and a variable the query does not select raises `IndexError`. `to_h` gives every binding.
- Results stream from the store one at a time and can be read once. Reading them again raises `Oxigraph::Error`; run the query again instead.
- Results come from a snapshot taken when the query ran, so a later `load` does not change them.
- Row order is only defined by `ORDER BY`.
- Blank node identifiers differ from one process to the next, so neither they nor an order based on them is stable.
- `prefixes:` and `base_iri:` declare prefixes and a base IRI without adding lines to the query text, which keeps the positions in error messages true to it.

### What a query cannot do

A query reads what the store holds and nothing else:

- **It never writes.** An update passed to `query` or `Query.parse` raises `Oxigraph::QuerySyntaxError`.
- **It never opens a network connection.** A query that contains `SERVICE`, `SERVICE SILENT` included, raises `Oxigraph::UnsupportedError` before it runs. `Query#service?` reports the same thing without running it.
- **`FROM` and `FROM NAMED` choose among the graphs in the store** and never fetch one. A graph the store does not hold matches nothing, so the query returns no rows rather than failing. `Query#dataset?` tells a caller that a query has such a clause, so it can refuse the query.

```ruby
Oxigraph::Query.parse("SELECT * FROM <http://example.com/g> WHERE { ?s ?p ?o }").dataset? # => true
Oxigraph::Query.parse("ASK { ?s ?p ?o }").form                                           # => :ask
```

`Oxigraph::Update.parse` recognizes a SPARQL update and cannot run it. It tells a valid update apart from text that is not SPARQL at all:

```ruby
Oxigraph::Update.parse("DROP ALL").to_s # => "DROP ALL ;"
Oxigraph::Update.parse("nonsense")      # raises Oxigraph::QuerySyntaxError
```

A query or update that does not parse raises `Oxigraph::QuerySyntaxError`, whose message gives the line and column. A query that fails while it runs raises `Oxigraph::QueryEvaluationError`.

## Terms

RDF terms are value objects:

```ruby
node = Oxigraph::NamedNode.new("http://example.com/a")
node.value # => "http://example.com/a"
node.to_s  # => "<http://example.com/a>"

Oxigraph::BlankNode.new("b0").to_s # => "_:b0"
Oxigraph::BlankNode.new.value      # => a generated identifier

literal = Oxigraph::Literal.new("chat", language: "fr")
literal.value    # => "chat"
literal.language # => "fr"
literal.datatype # => #<Oxigraph::NamedNode <http://www.w3.org/1999/02/22-rdf-syntax-ns#langString>>

integer = Oxigraph::NamedNode.new("http://www.w3.org/2001/XMLSchema#integer")
Oxigraph::Literal.new("1", datatype: integer).to_s # => "\"1\"^^<http://www.w3.org/2001/XMLSchema#integer>"

triple = Oxigraph::Triple.new(node, Oxigraph::NamedNode.new("http://example.com/p"), literal)
triple.subject # => #<Oxigraph::NamedNode <http://example.com/a>>
triple.to_s    # => "<http://example.com/a> <http://example.com/p> \"chat\"@fr"
```

- Terms are frozen. They compare by value with `==` and `eql?`, so they work as `Hash` keys.
- `to_s` is the N-Triples form.
- An invalid IRI, blank node identifier, or language tag raises `ArgumentError`.
- Literals compare by lexical form and datatype: `"1"` and `"01"` as `xsd:integer` are different terms.
- A language tag is lowercased.

## Scope and limitations

- A store is read through SPARQL queries. There is no way yet to add or remove single triples, match a triple pattern directly, run an update, or write RDF back out.
- A query reads the default graph unless it uses `GRAPH`, `FROM`, or `FROM NAMED`. A store has named graphs only when it loaded a format that names them.
- JSON-LD that refers to a remote context fails to load, because the gem never fetches anything.
- Stores live in memory only. The gem is built without RocksDB, so there is no on-disk store.
- The gem is built without an HTTP client, so it never opens a network connection.
- There are no precompiled gems, so every install compiles the Rust extension.
- Only Ruby 3.4 and 4.0 are tested.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT. See [LICENSE](LICENSE).
