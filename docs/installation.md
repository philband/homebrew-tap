# Installation

Install the tap formula directly:

```sh
brew install philband/tap/dotenvsec
```

The formula supports macOS arm64 and Linux amd64 and installs:

- `dotenvsec`
- `dotenvsec-provider-sops`
- Homebrew's `sops` formula as a runtime dependency

Intel macOS and Linux arm64 are not currently supported. YubiKey and Secure
Enclave age plugins are optional and are not installed by this formula.

Every formula checksum comes from an immutable upstream release after its SSH
tag signature, Cosign bundle, GitHub provenance attestations, checksums, and
archive contents have been independently verified by this tap.
