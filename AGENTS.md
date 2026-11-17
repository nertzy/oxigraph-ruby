# AGENTS.md

Guidance for coding agents working in this repository. Read [CONTRIBUTING.md](CONTRIBUTING.md) too.

## Layout

- `ext/oxigraph/`: the Rust native extension, built with magnus and rb-sys. Its crate is named `oxigraph`, the same as the upstream crate it wraps.
- `bin/`: checked-in development scripts. `setup` and `console` are hand-written; `rake` and `standardrb` are Bundler binstubs. None of them ship in the gem.
- `lib/`: the Ruby side of the gem. `lib/oxigraph.rb` loads the compiled extension.
- `test/`: Minitest tests, which exercise the extension through its Ruby API.
- `script/`: scripts the workflows run. `verify_native_gem.rb` installs a precompiled gem and uses it; `release_notes.rb` prints a version's section of the changelog.
- `Cargo.toml`, `Cargo.lock`: the Cargo workspace. Both ship in the gem.
- `.github/workflows/`: `ci.yml` gates pull requests; `release.yml` builds the source gem and the precompiled gems, installs each precompiled gem on its own platform, and publishes on a version tag after approval. [RELEASING.md](RELEASING.md) describes a release.

## Commands

```bash
bin/setup
bin/rake
bin/rake lint
bin/rake lint:fix
```

## Rules

- Write the failing test first for a behavior change.
- Test behavior from Ruby in `test/`, not with Rust unit tests: the embedded-Ruby test harness does not load on every supported Ruby.
- Results stream. Return an `Enumerator` or yield items one at a time; never build a whole result set as a Ruby array before returning it.
- Every file the gem needs at install time is listed in `spec.files` in `oxigraph.gemspec`. A new top-level file or extension file type needs an entry there.
- A change a user of the gem would notice adds an entry under `Unreleased` in `CHANGELOG.md`, beneath `Added`, `Changed`, `Fixed`, or `Removed` and starting with that word.
- Pin every GitHub Action to a full commit SHA with the tag in a trailing comment.
- Do not publish gems, push tags, or merge pull requests.
