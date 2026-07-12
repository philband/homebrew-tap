#!/usr/bin/env bash

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECTS_DIR="${PROJECTS_DIR:-$PROJECT_ROOT/projects}"

project_die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

project_manifest() {
  local project="$1"
  [[ "$project" =~ ^[a-z0-9][a-z0-9-]*$ ]] || project_die "invalid project slug: $project"
  local manifest="$PROJECTS_DIR/$project.yaml"
  [[ -f "$manifest" ]] || project_die "project manifest not found: $project"
  printf '%s' "$manifest"
}

manifest_read() {
  local manifest="$1"
  local expression="$2"
  yq -er "$expression" "$manifest"
}

manifest_read_raw() {
  local manifest="$1"
  local expression="$2"
  yq -r "$expression" "$manifest"
}

validate_manifest() {
  local manifest="$1"
  local project repository formula_path template_path checksum_asset bundle_asset

  [[ "$(manifest_read "$manifest" '.api_version')" == 1 ]] || project_die "unsupported manifest api_version"
  project="$(manifest_read "$manifest" '.project')"
  repository="$(manifest_read "$manifest" '.repository')"
  formula_path="$(manifest_read "$manifest" '.formula.path')"
  template_path="$(manifest_read "$manifest" '.formula.template')"
  checksum_asset="$(manifest_read "$manifest" '.release.checksums.asset')"
  bundle_asset="$(manifest_read "$manifest" '.release.cosign.bundle')"

  [[ "$project" =~ ^[a-z0-9][a-z0-9-]*$ ]] || project_die "invalid manifest project slug"
  [[ "$repository" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || project_die "invalid GitHub repository"
  [[ "$(manifest_read "$manifest" '.release.tag_signature.strategy')" == ssh-github ]] || project_die "unsupported tag signature strategy"
  [[ "$(manifest_read "$manifest" '.release.checksums.algorithm')" == sha256 ]] || project_die "unsupported checksum algorithm"
  [[ "$(manifest_read "$manifest" '.release.cosign.strategy')" == keyless-bundle ]] || project_die "unsupported Cosign strategy"
  [[ "$(manifest_read "$manifest" '.release.attestations.strategy')" == github ]] || project_die "unsupported attestation strategy"
  [[ "$formula_path" =~ ^Formula/[a-z0-9-]+\.rb$ ]] || project_die "unsafe formula path"
  [[ "$template_path" =~ ^templates/[a-z0-9-]+\.rb\.tmpl$ ]] || project_die "unsafe formula template path"
  [[ -f "$PROJECT_ROOT/$template_path" ]] || project_die "formula template does not exist"
  [[ "$(manifest_read "$manifest" '.release.cosign.certificate_identity')" == *'{tag}'* ]] || project_die "Cosign identity must bind the discovered tag"
  [[ "$(manifest_read "$manifest" '.release.archives | length')" -gt 0 ]] || project_die "at least one release archive is required"
  [[ "$(manifest_read_raw "$manifest" '.release.tag_prefix')" != null ]] || project_die "release tag_prefix is required"
  [[ "$(manifest_read "$manifest" '.archive.entries | length')" -gt 0 ]] || project_die "archive entries are required"
  [[ "$(manifest_read "$manifest" '.archive.executables | length')" -gt 0 ]] || project_die "archive executables are required"
  [[ "$(manifest_read_raw "$manifest" '.formula.dependencies')" != null ]] || project_die "formula dependencies are required"
  [[ "$(manifest_read "$manifest" '.ci.runners | length')" -gt 0 ]] || project_die "CI runners are required"

  local fixed_assets entries
  fixed_assets="$(yq -er '.release.assets.fixed[]' "$manifest")"
  entries="$(yq -er '.archive.entries[]' "$manifest")"
  [[ "$(printf '%s\n' "$fixed_assets" | wc -l | tr -d ' ')" == "$(printf '%s\n' "$fixed_assets" | LC_ALL=C sort -u | wc -l | tr -d ' ')" ]] || project_die "fixed release assets must be unique"
  [[ "$(printf '%s\n' "$entries" | wc -l | tr -d ' ')" == "$(printf '%s\n' "$entries" | LC_ALL=C sort -u | wc -l | tr -d ' ')" ]] || project_die "archive entries must be unique"
  while IFS= read -r asset; do
    [[ "$asset" =~ ^[A-Za-z0-9._-]+$ ]] || project_die "fixed asset must be a safe basename: $asset"
  done <<<"$fixed_assets"
  grep -Fxq "$checksum_asset" <<<"$fixed_assets" || project_die "checksum asset must be in the fixed asset allowlist"
  grep -Fxq "$bundle_asset" <<<"$fixed_assets" || project_die "Cosign bundle must be in the fixed asset allowlist"
  while IFS= read -r entry; do
    [[ "$entry" != /* && ! "$entry" =~ (^|/)\.\.(/|$) ]] || project_die "unsafe expected archive entry: $entry"
  done <<<"$entries"
  while IFS= read -r executable; do
    grep -Fxq "$executable" <<<"$entries" || project_die "archive executable is not an expected entry: $executable"
  done < <(yq -er '.archive.executables[]' "$manifest")

  local key format asset sbom
  local -a archive_keys=()
  while IFS=$'\t' read -r key format asset sbom; do
    [[ "$key" =~ ^[A-Z][A-Z0-9_]*$ ]] || project_die "invalid archive key: $key"
    [[ "$format" == tar.gz ]] || project_die "unsupported archive format: $format"
    [[ "$asset" == *'{version}'* ]] || project_die "archive asset must contain {version}"
    [[ "$sbom" == *'{version}'* ]] || project_die "SBOM asset must contain {version}"
    [[ "$asset" != */* && "$sbom" != */* ]] || project_die "asset templates must be basenames"
    archive_keys+=("$key")
  done < <(yq -er '.release.archives[] | [.key, .format, .asset, .sbom] | @tsv' "$manifest")
  [[ "${#archive_keys[@]}" == "$(printf '%s\n' "${archive_keys[@]}" | LC_ALL=C sort -u | wc -l | tr -d ' ')" ]] || project_die "archive keys must be unique"
}

expand_release_value() {
  local value="$1"
  local tag="$2"
  local version="$3"
  value="${value//\{tag\}/$tag}"
  value="${value//\{version\}/$version}"
  printf '%s' "$value"
}
