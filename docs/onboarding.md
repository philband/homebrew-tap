# Project onboarding

Adding a formula does not require copying a workflow or adding a manual release
tag input. Scheduled automation discovers projects from `projects/*.yaml`.

1. Copy `projects/example.yaml.disabled` to `projects/<project>.yaml` and fill
   every field using `projects/dotenvsec.yaml` as the complete example.
2. Add `templates/<project>.rb.tmpl`. Templates may use `{{PROJECT}}`,
   `{{REPOSITORY}}`, `{{TAG}}`, `{{VERSION}}`, and per-archive
   `{{ARCHIVE_<KEY>}}`/`{{SHA256_<KEY>}}` placeholders.
3. Declare every release asset exactly, including checksum and signature
   bundles, archives, and SBOMs. Declare every expected archive entry and
   executable.
4. Declare each supported Homebrew runner. CI installs and tests every generated
   project/runner combination.
5. Run the generic negative tests, update the project, and verify deterministic
   regeneration before opening a pull request.

The initial schema intentionally supports only the proven `ssh-github` signed
annotated-tag, keyless Cosign bundle, GitHub attestation, SHA-256, and `tar.gz`
profile. Add a new verifier implementation and negative tests before extending
the schema; never configure an unsigned or unchecked fallback.

An upstream project may optionally dispatch `{ "project": "<project>" }` with
event type `tap-release` for low latency. This is only a wake-up signal. The tap
always discovers the newest stable release tag itself, and scheduled polling is
authoritative when no upstream dispatch exists.
