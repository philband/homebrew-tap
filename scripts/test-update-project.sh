#!/usr/bin/env bash
set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/project-updater-test.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT
mkdir -p "$WORK_DIR/bin" "$WORK_DIR/assets" "$WORK_DIR/stage"

cat >"$WORK_DIR/bin/git" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"cat-file -t"* ]]; then printf 'tag\n'; fi
exit "${GIT_FAIL:-0}"
EOF

cat >"$WORK_DIR/bin/cosign" <<'EOF'
#!/usr/bin/env bash
exit "${COSIGN_FAIL:-0}"
EOF

cat >"$WORK_DIR/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$FIXTURE_DIR/api.log"

if [[ "$1" == api ]]; then
  endpoint="$2"
  case "$endpoint" in
    repos/*/releases/tags/*)
      printf '{"tag_name":"v0.1.0","draft":false,"prerelease":false,"immutable":%s,"assets":[' "$(cat "$FIXTURE_DIR/release-immutable")"
      separator=''
      while IFS= read -r asset; do
        printf '%s{"name":"%s"}' "$separator" "$asset"
        separator=','
      done <"$FIXTURE_DIR/assets.list"
      printf ']}\n'
      ;;
    repos/*/releases)
      cat "$FIXTURE_DIR/releases.tsv"
      ;;
    users/*/ssh_signing_keys)
      printf 'philband ssh-ed25519 AAAATEST\n'
      ;;
    *) exit 1 ;;
  esac
  exit 0
fi

if [[ "$1 $2" == "release download" ]]; then
  destination=''
  pattern=''
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dir) destination="$2"; shift 2 ;;
      --pattern) pattern="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  cp "$FIXTURE_DIR/$pattern" "$destination/$pattern"
  exit 0
fi

if [[ "$1 $2" == "attestation verify" ]]; then
  exit "${ATTESTATION_FAIL:-0}"
fi
exit 1
EOF
chmod +x "$WORK_DIR/bin/gh" "$WORK_DIR/bin/git" "$WORK_DIR/bin/cosign"

expect_failure() {
  local description="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    printf 'expected failure: %s\n' "$description" >&2
    exit 1
  fi
}

write_latest() {
  local tag="${1:-v0.1.0}"
  local draft="${2:-false}"
  local prerelease="${3:-false}"
  local immutable="${4:-true}"
  printf '%s\t%s\t%s\n' "$tag" "$draft" "$prerelease" >"$WORK_DIR/assets/releases.tsv"
  printf '%s\n' "$immutable" >"$WORK_DIR/assets/release-immutable"
}

write_assets() {
  cat >"$WORK_DIR/assets/assets.list" <<'EOF'
checksums.txt
checksums.txt.bundle
dotenvsec_0.1.0_darwin_arm64.tar.gz
dotenvsec_0.1.0_darwin_arm64.tar.gz.spdx.sbom
dotenvsec_0.1.0_linux_amd64.tar.gz
dotenvsec_0.1.0_linux_amd64.tar.gz.spdx.sbom
EOF
  : >"$WORK_DIR/assets/checksums.txt.bundle"
  : >"$WORK_DIR/assets/dotenvsec_0.1.0_darwin_arm64.tar.gz.spdx.sbom"
  : >"$WORK_DIR/assets/dotenvsec_0.1.0_linux_amd64.tar.gz.spdx.sbom"
  rm -rf "$WORK_DIR/stage"
  mkdir -p "$WORK_DIR/stage"
  printf 'license\n' >"$WORK_DIR/stage/LICENSE"
  printf 'readme\n' >"$WORK_DIR/stage/README.md"
  printf '#!/bin/sh\n' >"$WORK_DIR/stage/dotenvsec"
  printf '#!/bin/sh\n' >"$WORK_DIR/stage/dotenvsec-provider-sops"
  chmod 0755 "$WORK_DIR/stage/dotenvsec" "$WORK_DIR/stage/dotenvsec-provider-sops"
  for archive in dotenvsec_0.1.0_darwin_arm64.tar.gz dotenvsec_0.1.0_linux_amd64.tar.gz; do
    tar -czf "$WORK_DIR/assets/$archive" -C "$WORK_DIR/stage" LICENSE README.md dotenvsec dotenvsec-provider-sops
  done
  (
    cd "$WORK_DIR/assets"
    shasum -a 256 \
      dotenvsec_0.1.0_darwin_arm64.tar.gz \
      dotenvsec_0.1.0_darwin_arm64.tar.gz.spdx.sbom \
      dotenvsec_0.1.0_linux_amd64.tar.gz \
      dotenvsec_0.1.0_linux_amd64.tar.gz.spdx.sbom >checksums.txt
  )
  : >"$WORK_DIR/assets/api.log"
}

run_latest() {
  PATH="$WORK_DIR/bin:$PATH" FIXTURE_DIR="$WORK_DIR/assets" \
    "$ROOT/scripts/update-project.sh" dotenvsec "$WORK_DIR/output" "$WORK_DIR/metadata"
}

write_latest
write_assets
run_latest >/dev/null
grep -qx 'tag=v0.1.0' "$WORK_DIR/metadata"
test -f "$WORK_DIR/output/Formula/dotenvsec.rb"

write_assets
write_latest v1.2
expect_failure "malformed latest tag" run_latest

write_assets
write_latest v0.1.0 true false true
expect_failure "draft latest release" run_latest

write_assets
write_latest v0.1.0 false true true
expect_failure "prerelease latest release" run_latest

write_assets
write_latest v0.1.0 false false false
printf 'v0.0.9\tfalse\tfalse\n' >>"$WORK_DIR/assets/releases.tsv"
expect_failure "mutable newest release with older valid release" run_latest
if grep -q 'releases/tags/v0.0.9' "$WORK_DIR/assets/api.log"; then
  printf 'newest-release failure incorrectly fell back to an older release\n' >&2
  exit 1
fi

write_latest
write_assets
sed -i.bak '/linux_amd64.tar.gz.spdx.sbom/d' "$WORK_DIR/assets/assets.list"
expect_failure "missing release asset" run_latest

write_assets
printf 'unexpected.zip\n' >>"$WORK_DIR/assets/assets.list"
expect_failure "unexpected release asset" run_latest

write_assets
printf 'checksums.txt\n' >>"$WORK_DIR/assets/assets.list"
expect_failure "duplicate release asset" run_latest

write_assets
printf 'not-a-sha  dotenvsec_0.1.0_darwin_arm64.tar.gz\n' >"$WORK_DIR/assets/checksums.txt"
expect_failure "malformed checksum manifest" run_latest

write_assets
head -n 1 "$WORK_DIR/assets/checksums.txt" >>"$WORK_DIR/assets/checksums.txt"
expect_failure "duplicate checksum entries" run_latest

write_assets
COSIGN_FAIL=1 expect_failure "Cosign identity failure" run_latest

write_assets
ATTESTATION_FAIL=1 expect_failure "missing build attestation" run_latest

write_assets
printf 'unexpected\n' >"$WORK_DIR/stage/unexpected"
tar -czf "$WORK_DIR/assets/dotenvsec_0.1.0_darwin_arm64.tar.gz" -C "$WORK_DIR/stage" LICENSE README.md dotenvsec dotenvsec-provider-sops unexpected
(
  cd "$WORK_DIR/assets"
  shasum -a 256 dotenvsec_0.1.0_darwin_arm64.tar.gz dotenvsec_0.1.0_darwin_arm64.tar.gz.spdx.sbom dotenvsec_0.1.0_linux_amd64.tar.gz dotenvsec_0.1.0_linux_amd64.tar.gz.spdx.sbom >checksums.txt
)
expect_failure "unexpected archive entry" run_latest

write_assets
chmod 0644 "$WORK_DIR/stage/dotenvsec-provider-sops"
tar -czf "$WORK_DIR/assets/dotenvsec_0.1.0_darwin_arm64.tar.gz" -C "$WORK_DIR/stage" LICENSE README.md dotenvsec dotenvsec-provider-sops
(
  cd "$WORK_DIR/assets"
  shasum -a 256 dotenvsec_0.1.0_darwin_arm64.tar.gz dotenvsec_0.1.0_darwin_arm64.tar.gz.spdx.sbom dotenvsec_0.1.0_linux_amd64.tar.gz dotenvsec_0.1.0_linux_amd64.tar.gz.spdx.sbom >checksums.txt
)
expect_failure "non-executable archive binary" run_latest

fixtures="$WORK_DIR/projects"
mkdir -p "$fixtures"
cp "$ROOT/projects/dotenvsec.yaml" "$fixtures/dotenvsec.yaml"
yq -i '.release.tag_signature.strategy = "unsupported"' "$fixtures/dotenvsec.yaml"
expect_failure "unsupported verifier strategy" env PROJECTS_DIR="$fixtures" "$ROOT/scripts/project-matrix.sh" projects

cp "$ROOT/projects/dotenvsec.yaml" "$fixtures/dotenvsec.yaml"
yq -i 'del(.release.cosign.bundle)' "$fixtures/dotenvsec.yaml"
expect_failure "missing required security field" env PROJECTS_DIR="$fixtures" "$ROOT/scripts/project-matrix.sh" projects

projects_json="$($ROOT/scripts/project-matrix.sh projects dotenvsec)"
[[ "$projects_json" == *'"project":"dotenvsec"'* ]]
install_json="$($ROOT/scripts/project-matrix.sh install dotenvsec)"
[[ "$install_json" == *'"arch":"arm64"'* && "$install_json" == *'"arch":"x86_64"'* ]]

printf 'generic project updater tests passed\n'
