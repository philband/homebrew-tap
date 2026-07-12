# philband Homebrew tap

Reviewed Homebrew formulae published by Phil Band.

## Install dotenvsec

```sh
brew install philband/tap/dotenvsec
```

The formula supports macOS arm64 and Linux amd64. It installs both `dotenvsec`
and `dotenvsec-provider-sops`, plus the required Homebrew `sops` dependency.
Hardware-backed age plugins remain optional and must be installed separately.

The tap periodically discovers the latest stable release for every project in
`projects/`. Tags remain mandatory: the discovered release tag must be signed,
published, immutable, and satisfy the project's complete verification policy.
Automation opens a pull request and never writes directly to `main`.

See [the release workflow](docs/release-workflow.md) for the verification model
and [project onboarding](docs/onboarding.md) for adding future formulae.

Homebrew Core submission and bottles are intentionally deferred.
