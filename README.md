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

That is the whole API so far. Loading RDF and running SPARQL queries are next.

## Scope and limitations

- A store can be created and counted, and nothing can be loaded into it or queried yet.
- Stores live in memory only. The gem is built without RocksDB, so there is no on-disk store.
- The gem is built without an HTTP client, so it never opens a network connection.
- There are no precompiled gems, so every install compiles the Rust extension.
- Only Ruby 3.4 and 4.0 are tested.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT. See [LICENSE](LICENSE).
