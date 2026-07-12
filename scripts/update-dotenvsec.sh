#!/usr/bin/env bash
set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ $# -le 2 ]] || { printf 'usage: %s [output-root] [metadata-file]\n' "${0##*/}" >&2; exit 2; }
exec "$ROOT/scripts/update-project.sh" dotenvsec "${1:-.}" "${2:-}"
