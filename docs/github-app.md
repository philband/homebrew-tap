# GitHub App setup

Create a dedicated GitHub App for tap automation. Do not use a personal access
token.

## Repository permissions

- Metadata: read
- Contents: read and write
- Pull requests: read and write

No webhook subscriptions are required. Install the App only on
`philband/homebrew-tap`. The `dotenvsec` workflow can request an installation
token for that repository using the App credentials; it does not require the
App to be installed on `dotenvsec`.

Store these Actions secrets in both `philband/dotenvsec` and
`philband/homebrew-tap`:

- `HOMEBREW_TAP_APP_ID`
- `HOMEBREW_TAP_APP_PRIVATE_KEY`

The private key is stored as the complete PEM value. Never place credentials in
dispatch payloads, workflow logs, repository variables, or committed files.
An optional dispatch payload contains only `{ "project": "project-slug" }`.
The tap discovers the release tag itself and rejects payloads containing a tag.

After installing the App and protecting tap `main`, use the tap workflow's
input-free manual trigger to discover and verify the latest configured releases.
