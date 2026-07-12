# Security policy

Only the latest formula revision on `main` is supported.

Report vulnerabilities through GitHub private vulnerability reporting for this
repository. Do not disclose suspected release-signing, GitHub App, or formula
supply-chain issues in a public issue before a maintainer has investigated.

Formula updates discover each project's newest stable published release, then
verify its immutable release, annotated SSH tag, Cosign bundle, GitHub build
provenance, checksums, and archive contents before opening a reviewed pull
request. A broken newest release fails closed and never falls back to an older
release. Scheduled historical verification is read-only and opens an issue if
an already-published formula stops validating.
