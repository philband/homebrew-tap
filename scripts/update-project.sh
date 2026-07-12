#!/usr/bin/env bash
set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/project.sh"

[[ $# -ge 1 && $# -le 3 ]] || project_die "usage: ${0##*/} <project> [output-root] [metadata-file]"
readonly PROJECT="$1"
readonly OUTPUT_ROOT="${2:-.}"
readonly METADATA_FILE="${3:-}"
readonly MANIFEST="$(project_manifest "$PROJECT")"

for command in gh yq; do
  command -v "$command" >/dev/null || project_die "required command is unavailable: $command"
done
validate_manifest "$MANIFEST"
readonly REPOSITORY="$(manifest_read "$MANIFEST" '.repository')"
readonly TAG_PREFIX="$(manifest_read_raw "$MANIFEST" '.release.tag_prefix')"
readonly TAG_REGEX="$(manifest_read "$MANIFEST" '.release.tag_regex')"
readonly WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/homebrew-tap-discovery-${PROJECT}.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

gh api "repos/${REPOSITORY}/releases" --paginate --jq '.[] | [.tag_name, .draft, .prerelease] | @tsv' >"$WORK_DIR/releases"
while IFS=$'\t' read -r tag draft prerelease; do
  [[ "$draft" == false && "$prerelease" == false ]] || continue
  [[ "$tag" =~ $TAG_REGEX && "$tag" == "$TAG_PREFIX"* ]] || continue
  version="${tag#"$TAG_PREFIX"}"
  IFS=. read -r major minor patch <<<"$version"
  printf '%s\t%s\t%s\t%s\n' "$major" "$minor" "$patch" "$tag"
done <"$WORK_DIR/releases" | LC_ALL=C sort -t $'\t' -k1,1nr -k2,2nr -k3,3nr >"$WORK_DIR/candidates"

[[ -s "$WORK_DIR/candidates" ]] || project_die "no stable published semantic-version release is available"
readonly TAG="$(awk 'NR == 1 { print $4 }' "$WORK_DIR/candidates")"
[[ "$(awk -v tag="$TAG" '$4 == tag { count++ } END { print count + 0 }' "$WORK_DIR/candidates")" == 1 ]] || project_die "newest release tag is duplicated"

exec "$ROOT/scripts/verify-project.sh" "$PROJECT" "$TAG" "$OUTPUT_ROOT" "$METADATA_FILE"
