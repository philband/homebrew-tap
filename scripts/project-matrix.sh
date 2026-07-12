#!/usr/bin/env bash
set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/project.sh"

readonly MODE="${1:-projects}"
readonly TARGET="${2:-}"
declare -a OBJECTS=()

for manifest in "$PROJECTS_DIR"/*.yaml; do
  [[ "${manifest##*/}" == schema.yaml ]] && continue
  validate_manifest "$manifest"
  project="$(manifest_read "$manifest" '.project')"
  [[ -z "$TARGET" || "$project" == "$TARGET" ]] || continue
  case "$MODE" in
    projects)
      OBJECTS+=("$(PROJECT="$project" yq -n -o=json -I=0 '{"project": strenv(PROJECT)}')")
      ;;
    install)
      while IFS= read -r object; do OBJECTS+=("$object"); done < <(
        PROJECT="$project" yq -o=json -I=0 '.ci.runners[] | .project = strenv(PROJECT)' "$manifest"
      )
      ;;
    *) project_die "unsupported matrix mode: $MODE" ;;
  esac
done

[[ ${#OBJECTS[@]} -gt 0 ]] || project_die "no projects matched"
printf '{"include":['
separator=''
for object in "${OBJECTS[@]}"; do
  printf '%s%s' "$separator" "$object"
  separator=','
done
printf ']}\n'
