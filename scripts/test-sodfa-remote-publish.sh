#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PUBLISH_SCRIPT="$SCRIPT_DIR/sodfa-remote-publish.sh"
TMP_ROOT="$(mktemp -d)"
REMOTE_DIR="$TMP_ROOT/remote"
mkdir -p "$REMOTE_DIR"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

stage_release() {
  local build="$1"
  local apk_name="$2"
  local apk_content="$3"
  local manifest_version="$4"
  local signature="$5"

  printf '%s' "$apk_content" > "$REMOTE_DIR/.$apk_name.uploading"
  python3 - "$build" "$manifest_version" > "$REMOTE_DIR/.manifest.json.uploading" <<'PY'
import json,sys
print(json.dumps({
  "application_id":"com.sodfa.sodfa",
  "platform":"android",
  "channel":"stable",
  "version":sys.argv[2],
  "build_number":int(sys.argv[1]),
  "apk_url":f"https://example.invalid/updates/sodfa/sodfa-{sys.argv[2]}+{sys.argv[1]}.apk",
  "sha256":"0"*64
},separators=(",",":")))
PY
  printf '%s' "$signature" > "$REMOTE_DIR/.manifest.json.sig.uploading"
}

run_publish() {
  local build="$1"
  local version="$2"
  local apk_name="sodfa-$version+$build.apk"
  local apk="$REMOTE_DIR/.$apk_name.uploading"
  local digest
  digest="$(sha256sum "$apk" | awk '{print $1}')"
  bash "$PUBLISH_SCRIPT" "$REMOTE_DIR" "$apk_name" "$digest" "$build"
}

expect_publish_failure() {
  local build="$1"
  local version="$2"
  if run_publish "$build" "$version" >/dev/null 2>&1; then
    echo "Expected publication to fail for build $build, but it succeeded." >&2
    exit 1
  fi
}

# Publish a new version/build.
stage_release 10 "0.1.9" "APK-BUILD-10" "0.1.9" "SIGNATURE-10"
run_publish 10 "0.1.9"
test -s "$REMOTE_DIR/sodfa-0.1.9+10.apk"
test "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["build_number"])' "$REMOTE_DIR/manifest.json")" = "10"

# Idempotently accept the exact same build and all exact same bytes.
stage_release 10 "0.1.9" "APK-BUILD-10" "0.1.9" "SIGNATURE-10"
run_publish 10 "0.1.9"

# Reject the same build number when APK bytes differ.
stage_release 10 "0.1.9" "TAMPERED-APK" "0.1.9" "SIGNATURE-10"
expect_publish_failure 10 "0.1.9"
test "$(cat "$REMOTE_DIR/sodfa-0.1.9+10.apk")" = "APK-BUILD-10"

# Reject the same APK/build when the manifest/signature differ.
stage_release 10 "0.1.9" "APK-BUILD-10" "0.1.9" "ALTERED-SIGNATURE"
expect_publish_failure 10 "0.1.9"

# Publish a newer build, then reject an older release attempting rollback.
stage_release 11 "0.2.0" "APK-BUILD-11" "0.2.0" "SIGNATURE-11"
run_publish 11 "0.2.0"
stage_release 10 "0.1.9" "APK-BUILD-10" "0.1.9" "SIGNATURE-10"
expect_publish_failure 10 "0.1.9"
test "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["build_number"])' "$REMOTE_DIR/manifest.json")" = "11"

echo "SODFA remote publication tests passed: new release, idempotent retry, same-build tampering, and rollback rejection."
