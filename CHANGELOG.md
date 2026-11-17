# Changelog

Notable changes to `oxigraph` are documented here.

## [Unreleased]

### Added

- Added the gem scaffold: a Rust native extension that builds and loads on Ruby 3.4 and 4.0.
- Added `Oxigraph::Store`, an in-memory store backed by Oxigraph 0.5, with `#size` and `#empty?`.
- Added the term classes `Oxigraph::NamedNode`, `Oxigraph::BlankNode`, `Oxigraph::Literal`, and `Oxigraph::Triple`.
- Added `Oxigraph::Store#load`, which reads Turtle, RDF/XML, N-Triples, N-Quads, TriG, N3, and JSON-LD from a string, an `IO`, or a file, and returns an `Oxigraph::LoadSummary`.
- Added `Oxigraph::ParseError`, which carries the line and column of malformed RDF input.
- Added `Oxigraph::Store#query`, which runs `SELECT`, `ASK`, `CONSTRUCT`, and `DESCRIBE` queries and streams their results.
- Added `Oxigraph::Query.parse` and `Oxigraph::Update.parse`, which parse SPARQL without running it. A query reports its form and whether it has a `SERVICE` or a dataset clause.
- Added `Oxigraph::QuerySyntaxError`, which carries the line and column of a SPARQL syntax error and names a prefix that the text uses without declaring.
- Added `Oxigraph::QueryEvaluationError` and `Oxigraph::UnsupportedError`.
- Added precompiled gems for Linux (glibc and musl) and macOS on x86-64 and ARM64, and for Windows on x64 and ARM64. Installing on those platforms needs no Rust toolchain; other platforms compile the extension from the source gem.
