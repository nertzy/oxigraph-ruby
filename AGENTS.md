# AGENTS.md

Guidance for coding agents working in this repository. Read [CONTRIBUTING.md](CONTRIBUTING.md) too.

## Layout

- `ext/oxigraph/`: the Rust native extension, built with magnus and rb-sys. Its crate is named `oxigraph`, the same as the upstream crate it wraps.
- `bin/`: checked-in development scripts. `setup` and `console` are hand-written; `rake` and `standardrb` are Bundler binstubs. None of them ship in the gem.
- `lib/`: the Ruby side of the gem. `lib/oxigraph.rb` loads the compiled extension.
- `test/`: Minitest tests, which exercise the extension through its Ruby API.
- `Cargo.toml`, `Cargo.lock`: the Cargo workspace. Both ship in the gem.
- `.github/workflows/`: `ci.yml` gates pull requests; `build-gems.yml` cross-compiles platform gems.

## Commands

```bash
bin/setup
bin/rake
actionlint
npx --yes markdownlint-cli2@0.24.1 "**/*.md"
bin/standardrb --fix
cargo fmt --all
```

## Rules

- Write the failing test first for a behavior change.
- Test behavior from Ruby in `test/`, not with Rust unit tests: the embedded-Ruby test harness does not load on every supported Ruby.
- Results stream. Return an `Enumerator` or yield items one at a time; never build a whole result set as a Ruby array before returning it.
- Every file the gem needs at install time is listed in `spec.files` in `oxigraph.gemspec`. A new top-level file or extension file type needs an entry there.
- Pin every GitHub Action to a full commit SHA with the tag in a trailing comment.
- Do not publish gems, push tags, or merge pull requests.
