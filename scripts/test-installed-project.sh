#!/usr/bin/env bash
set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/project.sh"

[[ $# -eq 1 ]] || project_die "usage: ${0##*/} <project>"
readonly MANIFEST="$(project_manifest "$1")"
validate_manifest "$MANIFEST"
while IFS= read -r executable; do
  command -v "$executable" >/dev/null || project_die "installed executable is unavailable: $executable"
done < <(yq -er '.archive.executables[]' "$MANIFEST")
while IFS= read -r dependency; do
  brew list --formula "$dependency" >/dev/null || project_die "Homebrew dependency is unavailable: $dependency"
done < <(yq -er '.formula.dependencies[]' "$MANIFEST")
brew test "$(manifest_read "$MANIFEST" '.formula.tap_name')"
