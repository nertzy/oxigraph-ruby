# oxigraph-ruby

Ruby bindings for [Oxigraph](https://github.com/oxigraph/oxigraph), a SPARQL database and RDF toolkit. The gem is named `oxigraph` and wraps the Oxigraph Rust library in a native extension.

This is an unofficial binding and is not affiliated with the Oxigraph project.

## Install

The gem is not published to RubyGems yet. Build it from source by pointing Bundler at a commit of this repository:

```ruby
gem "oxigraph", git: "https://github.com/nertzy/oxigraph-ruby", ref: "<commit SHA>"
```

Building needs Ruby 3.4 or newer and a stable [Rust toolchain](https://rustup.rs).

## Stores and queries

The repository currently holds the project scaffold: the native extension builds and loads, and it exposes none of Oxigraph yet. The first example lands here with the first implementation pull request.

## Scope and limitations

- No Oxigraph API is exposed yet.
- There are no precompiled gems, so every install compiles the Rust extension.
- Only Ruby 3.4 and 4.0 are tested.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT. See [LICENSE](LICENSE).
