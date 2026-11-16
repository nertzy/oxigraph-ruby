# Changelog

Notable changes to `oxigraph` are documented here.

## [Unreleased]

### Added

- Added the gem scaffold: a Rust native extension that builds and loads on Ruby 3.4 and 4.0.
- Added `Oxigraph::Store`, an in-memory store backed by Oxigraph 0.5, with `#size` and `#empty?`.
- Added the term classes `Oxigraph::NamedNode`, `Oxigraph::BlankNode`, `Oxigraph::Literal`, and `Oxigraph::Triple`.
- Added `Oxigraph::Store#load`, which reads Turtle, RDF/XML, N-Triples, N-Quads, TriG, N3, and JSON-LD from a string, an `IO`, or a file, and returns an `Oxigraph::LoadSummary`.
- Added `Oxigraph::ParseError`, which carries the line and column of malformed RDF input.
