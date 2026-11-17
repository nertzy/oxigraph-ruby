# Contributing

Thanks for helping improve oxigraph-ruby.

## Development

You need:

- Ruby 3.4 or 4.0. The floor is `required_ruby_version` in [oxigraph.gemspec](oxigraph.gemspec), and the [CI workflow](.github/workflows/ci.yml) tests every supported version.
- A stable Rust toolchain with the `rustfmt` and `clippy` components.
- [jactionlint](https://jactionlint.jdx.dev/install) 2.6.0 and Node.js, for the workflow and Markdown linters. jactionlint checks the workflows' shell scripts only when [ShellCheck](https://www.shellcheck.net/) is installed, as it is in CI.

Supported Ruby versions are the ones in [normal maintenance](https://www.ruby-lang.org/en/downloads/branches/). Security-maintenance versions are not supported targets.

```bash
bin/setup
bin/rake
bin/rake lint
bin/rake lint:fix
bin/rake build
```

`bin/setup` installs the bundle and compiles the extension. `bin/rake` compiles the extension, runs the tests, and runs every linter: [Standard](https://github.com/standardrb/standard), `cargo fmt --check`, Clippy, jactionlint, and [markdownlint](https://github.com/DavidAnson/markdownlint-cli2). `bin/rake lint` runs the linters alone, and `bin/rake --tasks` lists the task for each, to run one. `bin/rake build` packages the gem into `pkg/`. `bin/console` opens IRB with the gem loaded.

The scripts in `bin/` are checked in. `bin/rake` and `bin/standardrb` are Bundler binstubs, so they run the bundled versions without `bundle exec`.

`bin/rake lint:fix` applies the fixes the linters can make: `standardrb --fix`, `cargo clippy --fix`, `cargo fmt`, `jactionlint --fix`, and `markdownlint-cli2 --fix`. Each applies only the fixes it considers safe, so run `bin/rake lint` afterwards for what is left. jactionlint checks the workflows and the Dependabot configuration.

`Gemfile.lock` is not checked in, so the bundle resolves to the newest allowed gems. `Cargo.lock` is checked in, because it ships in the gem and pins what a source install compiles.

Add or update tests for behavior changes. Behavior is tested from Ruby, in `test/`. Pull requests should explain the problem, the chosen behavior, and any user-visible documentation changes.

## Releasing

Releases are published by a GitHub Actions workflow, never from a maintainer's machine. See [RELEASING.md](RELEASING.md).

## Reporting bugs and proposing changes

Use [GitHub issues](https://github.com/nertzy/oxigraph-ruby/issues) for reproducible bugs and focused proposals. For vulnerabilities, follow [SECURITY.md](SECURITY.md) instead of opening a public issue.
