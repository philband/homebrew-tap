#!/usr/bin/env bash
set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/project.sh"

usage() {
  printf 'usage: %s <project> <tag> [output-root] [metadata-file]\n' "${0##*/}" >&2
  exit 2
}

[[ $# -ge 2 && $# -le 4 ]] || usage
readonly PROJECT="$1"
readonly TAG="$2"
readonly OUTPUT_ROOT="${3:-.}"
readonly METADATA_FILE="${4:-}"
readonly MANIFEST="$(project_manifest "$PROJECT")"

for command in gh git cosign yq shasum tar awk sort diff cmp mktemp; do
  command -v "$command" >/dev/null || project_die "required command is unavailable: $command"
done
validate_manifest "$MANIFEST"
[[ "$(manifest_read "$MANIFEST" '.project')" == "$PROJECT" ]] || project_die "manifest project mismatch"

readonly TAG_REGEX="$(manifest_read "$MANIFEST" '.release.tag_regex')"
[[ "$TAG" =~ $TAG_REGEX ]] || project_die "discovered tag does not satisfy project stable-tag policy: $TAG"
readonly TAG_PREFIX="$(manifest_read_raw "$MANIFEST" '.release.tag_prefix')"
[[ "$TAG" == "$TAG_PREFIX"* ]] || project_die "tag does not start with configured prefix"
readonly VERSION="${TAG#"$TAG_PREFIX"}"
readonly REPOSITORY="$(manifest_read "$MANIFEST" '.repository')"
readonly SIGNER="$(manifest_read "$MANIFEST" '.release.tag_signature.signer')"
readonly CHECKSUM_ASSET="$(manifest_read "$MANIFEST" '.release.checksums.asset')"
readonly BUNDLE_ASSET="$(manifest_read "$MANIFEST" '.release.cosign.bundle')"
readonly FORMULA_RELATIVE="$(manifest_read "$MANIFEST" '.formula.path')"
readonly TEMPLATE_RELATIVE="$(manifest_read "$MANIFEST" '.formula.template')"
readonly TAP_NAME="$(manifest_read "$MANIFEST" '.formula.tap_name')"

readonly WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/homebrew-tap-${PROJECT}.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

readonly RELEASE_API="repos/${REPOSITORY}/releases/tags/${TAG}"
gh api "$RELEASE_API" >"$WORK_DIR/release.json"
[[ "$(yq -er '.tag_name' "$WORK_DIR/release.json")" == "$TAG" ]] || project_die "release tag mismatch"
[[ "$(yq -r '.draft' "$WORK_DIR/release.json")" == false ]] || project_die "release is still a draft"
[[ "$(yq -r '.prerelease' "$WORK_DIR/release.json")" == false ]] || project_die "prereleases cannot update this tap"
[[ "$(yq -r '.immutable' "$WORK_DIR/release.json")" == true ]] || project_die "release is not immutable"

declare -a ARCHIVE_KEYS=()
declare -a ARCHIVE_ASSETS=()
declare -a CHECKSUMMED_ASSETS=()
while IFS=$'\t' read -r key asset_template sbom_template; do
  asset="$(expand_release_value "$asset_template" "$TAG" "$VERSION")"
  sbom="$(expand_release_value "$sbom_template" "$TAG" "$VERSION")"
  [[ "$asset" =~ ^[A-Za-z0-9._-]+$ && "$sbom" =~ ^[A-Za-z0-9._-]+$ ]] || project_die "expanded asset name is unsafe"
  ARCHIVE_KEYS+=("$key")
  ARCHIVE_ASSETS+=("$asset")
  CHECKSUMMED_ASSETS+=("$asset" "$sbom")
done < <(yq -er '.release.archives[] | [.key, .asset, .sbom] | @tsv' "$MANIFEST")

{
  yq -er '.release.assets.fixed[]' "$MANIFEST"
  printf '%s\n' "${CHECKSUMMED_ASSETS[@]}"
} | LC_ALL=C sort >"$WORK_DIR/expected-assets"
yq -er '.assets[].name' "$WORK_DIR/release.json" | LC_ALL=C sort >"$WORK_DIR/actual-assets"
diff -u "$WORK_DIR/expected-assets" "$WORK_DIR/actual-assets" || project_die "release assets do not exactly match the allowlist"

readonly TAG_REPOSITORY="$WORK_DIR/tag-repository"
git -C "$WORK_DIR" init --quiet tag-repository
git -C "$TAG_REPOSITORY" fetch --quiet --no-tags "https://github.com/${REPOSITORY}.git" "refs/tags/${TAG}:refs/tags/${TAG}"
[[ "$(git -C "$TAG_REPOSITORY" cat-file -t "$TAG")" == tag ]] || project_die "release tag is not annotated"
gh api "users/${SIGNER}/ssh_signing_keys" --jq ".[] | \"${SIGNER} \\(.key)\"" >"$WORK_DIR/allowed-signers"
[[ -s "$WORK_DIR/allowed-signers" ]] || project_die "no SSH signing keys found for $SIGNER"
git -C "$TAG_REPOSITORY" config gpg.format ssh
git -C "$TAG_REPOSITORY" config gpg.ssh.allowedSignersFile "$WORK_DIR/allowed-signers"
git -C "$TAG_REPOSITORY" verify-tag "$TAG"

readonly ASSET_DIR="$WORK_DIR/assets"
mkdir -p "$ASSET_DIR"
while IFS= read -r asset; do
  gh release download "$TAG" --repo "$REPOSITORY" --dir "$ASSET_DIR" --pattern "$asset"
done <"$WORK_DIR/expected-assets"

identity="$(expand_release_value "$(manifest_read "$MANIFEST" '.release.cosign.certificate_identity')" "$TAG" "$VERSION")"
cosign verify-blob --bundle "$ASSET_DIR/$BUNDLE_ASSET" --certificate-identity "$identity" \
  --certificate-oidc-issuer "$(manifest_read "$MANIFEST" '.release.cosign.oidc_issuer')" "$ASSET_DIR/$CHECKSUM_ASSET"

printf '%s\n' "${CHECKSUMMED_ASSETS[@]}" | LC_ALL=C sort >"$WORK_DIR/expected-checksummed-assets"
awk 'NF != 2 || $1 !~ /^[0-9a-f]{64}$/ { exit 1 } { print $2 }' "$ASSET_DIR/$CHECKSUM_ASSET" |
  LC_ALL=C sort >"$WORK_DIR/checksummed-assets" || project_die "checksum manifest is malformed"
diff -u "$WORK_DIR/expected-checksummed-assets" "$WORK_DIR/checksummed-assets" || project_die "checksum manifest membership is invalid"
(cd "$ASSET_DIR" && shasum -a 256 -c "$CHECKSUM_ASSET")
while IFS= read -r asset; do
  gh attestation verify "$ASSET_DIR/$asset" --repo "$REPOSITORY" >/dev/null
done <"$WORK_DIR/expected-checksummed-assets"

yq -er '.archive.entries[]' "$MANIFEST" | LC_ALL=C sort >"$WORK_DIR/expected-archive-entries"
for archive in "${ARCHIVE_ASSETS[@]}"; do
  tar -tzf "$ASSET_DIR/$archive" | LC_ALL=C sort >"$WORK_DIR/archive-entries"
  diff -u "$WORK_DIR/expected-archive-entries" "$WORK_DIR/archive-entries" || project_die "$archive has unexpected, missing, duplicate, or unsafe paths"
  tar -tvzf "$ASSET_DIR/$archive" | awk '$1 !~ /^-/ { exit 1 }' || project_die "$archive contains non-regular files"
  while IFS= read -r executable; do
    tar -tvzf "$ASSET_DIR/$archive" | awk -v executable="$executable" '$NF == executable { found++; if ($1 !~ /x/) exit 1 } END { if (found != 1) exit 1 }' ||
      project_die "$archive has a missing, duplicate, or non-executable binary: $executable"
  done < <(yq -er '.archive.executables[]' "$MANIFEST")
done

checksum_for() {
  local asset="$1"
  local checksum
  checksum="$(awk -v asset="$asset" '$2 == asset { count++; value=$1 } END { if (count == 1) print value }' "$ASSET_DIR/$CHECKSUM_ASSET")"
  [[ "$checksum" =~ ^[0-9a-f]{64}$ ]] || project_die "missing or duplicate checksum for $asset"
  printf '%s' "$checksum"
}

rendered="$(cat "$ROOT/$TEMPLATE_RELATIVE")"
rendered="${rendered//'{{PROJECT}}'/$PROJECT}"
rendered="${rendered//'{{REPOSITORY}}'/$REPOSITORY}"
rendered="${rendered//'{{TAG}}'/$TAG}"
rendered="${rendered//'{{VERSION}}'/$VERSION}"
for index in "${!ARCHIVE_KEYS[@]}"; do
  key="${ARCHIVE_KEYS[$index]}"
  archive="${ARCHIVE_ASSETS[$index]}"
  checksum="$(checksum_for "$archive")"
  rendered="${rendered//\{\{ARCHIVE_${key}\}\}/$archive}"
  rendered="${rendered//\{\{SHA256_${key}\}\}/$checksum}"
done
[[ "$rendered" != *'{{'* && "$rendered" != *'}}'* ]] || project_die "formula template contains unresolved placeholders"

readonly FORMULA_PATH="$OUTPUT_ROOT/$FORMULA_RELATIVE"
mkdir -p "$(dirname "$FORMULA_PATH")"
readonly FIRST_RENDER="$WORK_DIR/formula.first"
readonly SECOND_RENDER="$WORK_DIR/formula.second"
printf '%s\n' "$rendered" >"$FIRST_RENDER"
printf '%s\n' "$rendered" >"$SECOND_RENDER"
cmp "$FIRST_RENDER" "$SECOND_RENDER" >/dev/null || project_die "formula rendering is not deterministic"
changed=true
[[ -f "$FORMULA_PATH" ]] && cmp "$FIRST_RENDER" "$FORMULA_PATH" >/dev/null && changed=false
readonly ATOMIC_RENDER="$(mktemp "$(dirname "$FORMULA_PATH")/.${PROJECT}.rb.XXXXXX")"
trap 'rm -rf "$WORK_DIR"; rm -f "$ATOMIC_RENDER"' EXIT
cp "$FIRST_RENDER" "$ATOMIC_RENDER"
chmod 0644 "$ATOMIC_RENDER"
mv "$ATOMIC_RENDER" "$FORMULA_PATH"

if [[ -n "$METADATA_FILE" ]]; then
  mkdir -p "$(dirname "$METADATA_FILE")"
  cat >"$METADATA_FILE" <<EOF
project=$PROJECT
tag=$TAG
version=$VERSION
formula=$FORMULA_RELATIVE
tap_name=$TAP_NAME
changed=$changed
EOF
fi
printf 'generated %s from verified immutable release %s\n' "$FORMULA_PATH" "$TAG"
