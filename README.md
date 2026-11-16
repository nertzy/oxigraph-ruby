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

Loading RDF and running SPARQL queries are next.

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

- A store can be created and counted, and terms can be built, and nothing can be loaded into a store or queried yet.
- Stores live in memory only. The gem is built without RocksDB, so there is no on-disk store.
- The gem is built without an HTTP client, so it never opens a network connection.
- There are no precompiled gems, so every install compiles the Rust extension.
- Only Ruby 3.4 and 4.0 are tested.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT. See [LICENSE](LICENSE).
