set shell := ["bash", "-euo", "pipefail", "-c"]

aqua_config := justfile_directory() / "aqua/aqua.yaml"
aqua := "AQUA_CONFIG=" + quote(aqua_config) + " aqua exec --"

default:
    @just --list

tools:
    AQUA_CONFIG={{quote(aqua_config)}} aqua install

tools-update:
    cd aqua && aqua up

tools-checksum:
    cd aqua && aqua upc --prune

tools-verify:
    cd aqua && aqua upc --prune
    git diff --exit-code -- aqua/aqua.yaml aqua/aqua-checksums.json

workflow-lint:
    {{aqua}} actionlint

actions-pinned:
    @if grep -RInE 'uses: [^./][^@[:space:]]+@(v?[0-9]+|main|master)([[:space:]#]|$$)' .github; then \
        echo "Every third-party action must use a full immutable commit SHA." >&2; \
        exit 1; \
    fi

project-matrix mode="projects" project="":
    @{{aqua}} bash scripts/project-matrix.sh {{quote(mode)}} {{quote(project)}}

project-update project output="." metadata="":
    {{aqua}} bash scripts/update-project.sh {{quote(project)}} {{quote(output)}} {{quote(metadata)}}

project-verify project output=".":
    tag=$({{aqua}} bash scripts/committed-tag.sh {{quote(project)}}); {{aqua}} bash scripts/verify-project.sh {{quote(project)}} "$tag" {{quote(output)}}

projects-update:
    for manifest in projects/*.yaml; do \
        project=$(basename "$manifest" .yaml); \
        [[ "$project" == schema ]] && continue; \
        {{aqua}} bash scripts/update-project.sh "$project" .; \
    done

formula-style project:
    formula=$({{aqua}} yq -er '.formula.path' projects/{{project}}.yaml); brew style "$formula"

formula-audit project:
    tap_name=$({{aqua}} yq -er '.formula.tap_name' projects/{{project}}.yaml); brew audit --strict --online "$tap_name"

formula-install project:
    tap_name=$({{aqua}} yq -er '.formula.tap_name' projects/{{project}}.yaml); brew install "$tap_name"

formula-test project:
    {{aqua}} bash scripts/test-installed-project.sh {{quote(project)}}

generator-negative-tests:
    {{aqua}} bash scripts/test-update-project.sh

verify: tools-verify workflow-lint actions-pinned generator-negative-tests
    for manifest in projects/*.yaml; do \
        project=$(basename "$manifest" .yaml); \
        [[ "$project" == schema ]] && continue; \
        just project-verify "$project"; \
        just formula-style "$project"; \
        just formula-audit "$project"; \
    done
