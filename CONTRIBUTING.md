# Contributing

Thanks for your interest in improving the official Ipregistry Ruby client.

## Development

The gem targets Ruby 3.1+ and has **no runtime dependencies** — please keep it that way (standard library only).
Development dependencies are managed with Bundler:

```bash
bundle install
```

Common tasks are wired through the `Rakefile`:

```bash
bundle exec rake spec      # run the unit/behavior specs (offline, WebMock)
bundle exec rake system    # run the live-API system specs (requires IPREGISTRY_API_KEY)
bundle exec rake rubocop   # lint
bundle exec rake build     # build the gem into pkg/
bundle exec rake           # default: rubocop + spec
```

Before opening a pull request, please make sure `bundle exec rake` passes.

## Guidelines

- **Public API stability.** This gem is 1.x; avoid breaking changes to the public API. If a breaking change is
  unavoidable, it must go through a new major version.
- **Naming.** Follow Ruby conventions: snake_case methods, predicate methods ending in `?` for booleans, keyword
  arguments for options.
- **Errors.** Surface API failures as `Ipregistry::ApiError` subclasses and client-side failures as
  `Ipregistry::ClientError` subclasses; let Ruby's exception `#cause` chain carry the underlying error.
- **Tests.** Add or update specs for any behavior change. Offline behavior is tested with WebMock; no live API key is
  required. Live system specs live in `spec/system` and run against the real API when `IPREGISTRY_API_KEY` is set;
  they consume credits, so keep them minimal.
- **Docs.** Keep the `README.md`, doc comments, and runnable examples in `examples/` in sync with the code.
- **Changelog.** Record notable changes in `CHANGELOG.md` under `[Unreleased]`.

## Releasing

Releases are performed by the manually triggered [Release workflow](.github/workflows/release.yml): bump
`lib/ipregistry/version.rb`, move the `[Unreleased]` notes to a new `## [X.Y.Z] - <date>` section in `CHANGELOG.md`,
merge to `main`, then dispatch the workflow with the version. It validates everything, runs the full test gate
(including live system specs), creates the `vX.Y.Z` tag and GitHub Release, and publishes the gem to RubyGems.

## Reporting issues

For bugs or feature requests, please open a GitHub issue. For account or API questions, contact
[support@ipregistry.co](mailto:support@ipregistry.co).
