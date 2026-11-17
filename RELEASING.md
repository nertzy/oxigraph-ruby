# Releasing

A release is a version tag. Pushing one starts the [Release workflow](.github/workflows/release.yml), which builds every gem, checks them, waits for approval, and publishes to RubyGems. Nothing is published from a maintainer's machine.

## What the workflow does

1. Checks the tag, then builds the source gem and one precompiled gem for each supported platform.
2. Installs each precompiled gem on its own platform, on Ruby 3.4 and 4.0, and runs a query with it. The Linux gems are installed in containers that have no compiler, so a gem cannot pass by compiling its extension.
3. Waits at the `release` environment until a reviewer approves the deployment.
4. Signs each gem with Sigstore and pushes it to RubyGems through [trusted publishing](https://guides.rubygems.org/trusted-publishing/). No API key is stored.
5. For a final version, creates a GitHub Release whose notes are that version's section of `CHANGELOG.md`.

The gems that are pushed are the ones step 2 installed, not a rebuild of them.

A manual run of the workflow, even one started from a tag, or a pull request that changes it, runs steps 1 and 2 only. Use a manual run to check a commit before tagging it.

## The changelog

`CHANGELOG.md` is written by hand. A change that a user of the gem would notice adds an entry under `Unreleased`, in the pull request that makes the change. Each entry sits under `Added`, `Changed`, `Fixed`, or `Removed` and starts with that word.

A final release moves the `Unreleased` entries under a `## [<version>] - YYYY-MM-DD` heading and leaves an empty `## [Unreleased]` above it. The workflow refuses a final version's tag when that section is missing or empty, and the section becomes the notes of the GitHub Release.

## One-time setup

- **RubyGems:** a trusted publisher for the `oxigraph` gem that names this repository, the workflow file `release.yml`, and the environment `release`. Before the gem's first release this is a pending trusted publisher on the account that will own the gem. A pending trusted publisher expires 12 hours after it is created, so create it shortly before pushing the first tag. Its page shows the account's ID.
- **GitHub:** an environment named `release` with required reviewers and a variable named `RUBYGEMS_OWNER` that holds that account's ID. The publish job sends it to RubyGems, which creates a new gem only for the account the workflow names.

## Cutting a release

1. Open a pull request that:
   - sets `VERSION` in `lib/oxigraph/version.rb`;
   - for a final release, sets the same `version` in `ext/oxigraph/Cargo.toml`, runs `bin/rake compile` so `Cargo.lock` follows, and gives the version its section of `CHANGELOG.md`. `ruby script/release_notes.rb <version>` prints the release notes that section will become.
2. Merge it once CI is green.
3. Tag the merge commit `v<version>` with a signed, annotated tag, and push the tag. A pushed release tag cannot be moved or deleted, so check its name and commit first.
4. Watch the Release run. When every install job is green, approve the `release` deployment.
5. Check the result from a machine that has never built the gem:

   ```bash
   gem list --remote --exact oxigraph --prerelease
   gem install oxigraph --version <version>
   ruby -e 'require "oxigraph"; puts Oxigraph::Store.new.size'
   ```

6. For a final release, check that the GitHub Release for the tag exists and shows that version's changelog section.

## Release candidates

A release candidate is a version such as `0.2.0.rc1`, tagged `v0.2.0.rc1`. Only `lib/oxigraph/version.rb` changes: Cargo does not accept that version format, so the crate keeps the final version. The changelog entries stay under `Unreleased`, and no GitHub Release is created. RubyGems installs a release candidate only when asked for it by version or with `--pre`.

## When something goes wrong

- **The tag does not match `VERSION`:** the run stops before building, and that tag name is spent. Release the next version number from a commit whose `VERSION` matches its tag.
- **A final version has no changelog section:** the run stops before building, the same way.
- **A build or install job fails:** nothing is published. Fix it through a pull request and release a new version from the fixed commit.
- **Publishing fails partway:** run the failed job again. Gems that RubyGems already has are skipped.
- **A published gem is broken:** yank it with `gem yank` and release a new version. RubyGems never lets a version number be used twice.
