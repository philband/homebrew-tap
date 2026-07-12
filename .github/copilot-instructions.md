# Repository instructions

- Treat project manifests, formula templates, and `scripts/update-project.sh`
  as the only sources for generated formulae; do not hand-edit generated
  versions or checksums.
- Preserve strict immutable-release, asset-allowlist, SSH tag, Cosign,
  attestation, checksum, and archive-content verification.
- Pin every third-party GitHub Action to a full 40-character commit SHA.
- Install command-line workflow tools only through the checksum-locked Aqua
  configuration; Homebrew itself is provided by the pinned Homebrew action.
- Formula updates must use version branches and reviewed pull requests. Never
  automate writes directly to `main`.
- Release tags are discovered from GitHub's latest stable published release.
  Never accept a tag or checksum from manual or dispatch workflow inputs, and
  never fall back when the newest release fails verification.
- Use tap-qualified names such as `philband/tap/dotenvsec` for modern Homebrew
  audit and install commands.
- Run generator negative tests, Actionlint, Aqua lock verification,
  deterministic regeneration, Homebrew style/audit, and supported-platform
  install tests before merging.
