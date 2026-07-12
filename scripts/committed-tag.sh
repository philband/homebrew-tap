#!/usr/bin/env bash
set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/project.sh"

[[ $# -eq 1 ]] || project_die "usage: ${0##*/} <project>"
readonly MANIFEST="$(project_manifest "$1")"
validate_manifest "$MANIFEST"
readonly FORMULA="$(manifest_read "$MANIFEST" '.formula.path')"
readonly PREFIX="$(manifest_read_raw "$MANIFEST" '.release.tag_prefix')"
version="$(sed -nE 's/^  version "([0-9]+\.[0-9]+\.[0-9]+)"$/\1/p' "$ROOT/$FORMULA")"
[[ "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || project_die "formula has no unique stable semantic version"
printf '%s%s\n' "$PREFIX" "$version"
