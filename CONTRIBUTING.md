# Contributing

Thanks for helping improve oxigraph-ruby.

## Development

You need:

- Ruby 3.4 or 4.0. The floor is `required_ruby_version` in [oxigraph.gemspec](oxigraph.gemspec), and the [CI workflow](.github/workflows/ci.yml) tests every supported version.
- A stable Rust toolchain with the `rustfmt` and `clippy` components.
- [actionlint](https://github.com/rhysd/actionlint) 1.7.12 and Node.js, for the workflow and Markdown linters.

Supported Ruby versions are the ones in [normal maintenance](https://www.ruby-lang.org/en/downloads/branches/). Security-maintenance versions are not supported targets.

```bash
bin/setup
bin/rake
actionlint
npx --yes markdownlint-cli2@0.24.1 "**/*.md"
bin/rake build
```

`bin/setup` installs the bundle and compiles the extension. `bin/rake` compiles the extension, runs the tests, and runs [Standard](https://github.com/standardrb/standard), `cargo fmt --check`, and Clippy. `bin/rake build` packages the gem into `pkg/`. `bin/console` opens IRB with the gem loaded.

The scripts in `bin/` are checked in. `bin/rake` and `bin/standardrb` are Bundler binstubs, so they run the bundled versions without `bundle exec`.

Run `bin/standardrb --fix` and `cargo fmt --all` to apply the fixes those tools can make. `actionlint` reports workflow problems but does not modify workflow files.

`Gemfile.lock` is not checked in, so the bundle resolves to the newest allowed gems. `Cargo.lock` is checked in, because it ships in the gem and pins what a source install compiles.

Add or update tests for behavior changes. Behavior is tested from Ruby, in `test/`. Pull requests should explain the problem, the chosen behavior, and any user-visible documentation changes.

## Reporting bugs and proposing changes

Use [GitHub issues](https://github.com/nertzy/oxigraph-ruby/issues) for reproducible bugs and focused proposals. For vulnerabilities, follow [SECURITY.md](SECURITY.md) instead of opening a public issue.
