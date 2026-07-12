# Formula release workflow

Every six hours, and on an input-free manual run, the tap enumerates all
`projects/*.yaml` manifests. An upstream repository may optionally send a
`repository_dispatch` containing only a project slug to wake discovery sooner.
Tags and checksums are never accepted from dispatch payloads.

For each project, the tap independently:

1. Queries GitHub's latest stable published release and discovers its tag.
2. Requires the discovered tag to satisfy the project's semantic-version policy
   and the release to be immutable, non-draft, and non-prerelease.
3. Requires exactly the manifest-declared archives, SBOMs, checksum file, and
   signature bundle.
4. Fetches the annotated tag and verifies its SSH signature against the
   configured signer's GitHub signing keys.
5. Verifies the manifest-declared keyless Cosign identity for that exact tag.
6. Verifies every checksum and GitHub build-provenance attestation.
7. Rejects malformed, duplicate, unsafe, missing, or unexpected archive paths
   and requires declared binaries to be executable.
8. Renders the project template twice, requires byte identity, atomically
   updates the formula, and opens or updates `updates/<project>-<tag>` using a
   least-privilege GitHub App token.

If the newest release fails any gate, discovery fails and reports the error. It
never silently falls back to an older valid release.

Automation never pushes to `main`. Protect `main` with required pull requests,
CI checks, conversation resolution, linear history, and disabled force-pushes
and deletion.

If dispatch or generation fails, rerun **Update formulas** without inputs. The
tap rediscovers the latest release and updates the same version branch and pull
request. Scheduled committed-release verification is separate and read-only;
it revalidates each formula's exact existing release and opens a project-specific
issue instead of rewriting formula history.

Homebrew Core submission and bottles are deferred.
