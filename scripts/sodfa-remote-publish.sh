#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 4 ]; then
  echo "Usage: sodfa-remote-publish.sh REMOTE_DIR APK_NAME APK_SHA256 BUILD_NUMBER" >&2
  exit 64
fi

REMOTE_DIR=$1
APK_NAME=$2
APK_SHA256=$3
BUILD_NUMBER=$4

if ! [[ "$APK_NAME" =~ ^sodfa-[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+\.apk$ ]]; then
  echo "Invalid SODFA APK filename." >&2
  exit 64
fi
if ! [[ "$APK_SHA256" =~ ^[a-f0-9]{64}$ ]]; then
  echo "Invalid APK SHA-256 digest." >&2
  exit 64
fi
if ! [[ "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
  echo "Invalid SODFA build number." >&2
  exit 64
fi

REMOTE_APK_TMP="$REMOTE_DIR/.$APK_NAME.uploading"
REMOTE_MANIFEST_TMP="$REMOTE_DIR/.manifest.json.uploading"
REMOTE_SIG_TMP="$REMOTE_DIR/.manifest.json.sig.uploading"
trap 'rm -f -- "$REMOTE_APK_TMP" "$REMOTE_MANIFEST_TMP" "$REMOTE_SIG_TMP"' EXIT

test -d "$REMOTE_DIR"
test -s "$REMOTE_APK_TMP"
test -s "$REMOTE_MANIFEST_TMP"
test -s "$REMOTE_SIG_TMP"

UPLOADED_SHA="$(sha256sum "$REMOTE_APK_TMP" | awk '{print $1}')"
if [ "$UPLOADED_SHA" != "$APK_SHA256" ]; then
  echo "Uploaded APK SHA-256 does not match the release artifact." >&2
  exit 1
fi

MANIFEST_FIELDS="$(python3 -c 'import json,re,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); v=d.get("version"); b=d.get("build_number"); h=d.get("sha256"); assert isinstance(v,str) and re.fullmatch(r"[0-9]+\\.[0-9]+\\.[0-9]+",v); assert isinstance(b,int) and not isinstance(b,bool) and b > 0; assert isinstance(h,str) and re.fullmatch(r"[a-f0-9]{64}",h); assert d.get("application_id") == "com.sodfa.sodfa" and d.get("platform") == "android" and d.get("channel") == "stable"; print(v,b,h,sep="\\t")' "$REMOTE_MANIFEST_TMP")"
IFS=

CURRENT_MANIFEST="$REMOTE_DIR/manifest.json"
CURRENT_SIGNATURE="$REMOTE_DIR/manifest.json.sig"
CURRENT_APK="$REMOTE_DIR/$APK_NAME"

if [ -s "$CURRENT_MANIFEST" ]; then
  CURRENT_BUILD="$(python3 -c 'import json,sys; print(int(json.load(open(sys.argv[1], encoding="utf-8"))["build_number"]))' "$CURRENT_MANIFEST")"

  if [ "$CURRENT_BUILD" -gt "$BUILD_NUMBER" ]; then
    echo "Refusing to publish an older build over a newer release." >&2
    exit 1
  fi

  if [ "$CURRENT_BUILD" -eq "$BUILD_NUMBER" ]; then
    test -s "$CURRENT_APK"
    test -s "$CURRENT_SIGNATURE"
    CURRENT_APK_SHA="$(sha256sum "$CURRENT_APK" | awk '{print $1}')"
    if [ "$CURRENT_APK_SHA" != "$APK_SHA256" ] ||
       ! cmp -s "$CURRENT_MANIFEST" "$REMOTE_MANIFEST_TMP" ||
       ! cmp -s "$CURRENT_SIGNATURE" "$REMOTE_SIG_TMP"; then
      echo "Refusing to replace an existing build number with different release bytes." >&2
      exit 1
    fi
    echo "This exact SODFA build is already published; no replacement is needed."
    exit 0
  fi
fi

if [ -e "$CURRENT_APK" ]; then
  EXISTING_SHA="$(sha256sum "$CURRENT_APK" | awk '{print $1}')"
  if [ "$EXISTING_SHA" != "$APK_SHA256" ]; then
    echo "Refusing to replace a published APK filename with different bytes." >&2
    exit 1
  fi
fi

mv -- "$REMOTE_APK_TMP" "$CURRENT_APK"
mv -- "$REMOTE_SIG_TMP" "$CURRENT_SIGNATURE"
mv -- "$REMOTE_MANIFEST_TMP" "$CURRENT_MANIFEST"
echo "Published SODFA build $BUILD_NUMBER."
\\t' read -r MANIFEST_VERSION MANIFEST_BUILD MANIFEST_SHA <<< "$MANIFEST_FIELDS"
if [ "$MANIFEST_BUILD" != "$BUILD_NUMBER" ] ||
   [ "$MANIFEST_SHA" != "$APK_SHA256" ] ||
   [ "$APK_NAME" != "sodfa-$MANIFEST_VERSION+$BUILD_NUMBER.apk" ]; then
  echo "Manifest application, version, build number, or APK digest does not match the release artifact." >&2
  exit 1
fi

CURRENT_MANIFEST="$REMOTE_DIR/manifest.json"
CURRENT_SIGNATURE="$REMOTE_DIR/manifest.json.sig"
CURRENT_APK="$REMOTE_DIR/$APK_NAME"

if [ -s "$CURRENT_MANIFEST" ]; then
  CURRENT_BUILD="$(python3 -c 'import json,sys; print(int(json.load(open(sys.argv[1], encoding="utf-8"))["build_number"]))' "$CURRENT_MANIFEST")"

  if [ "$CURRENT_BUILD" -gt "$BUILD_NUMBER" ]; then
    echo "Refusing to publish an older build over a newer release." >&2
    exit 1
  fi

  if [ "$CURRENT_BUILD" -eq "$BUILD_NUMBER" ]; then
    test -s "$CURRENT_APK"
    test -s "$CURRENT_SIGNATURE"
    CURRENT_APK_SHA="$(sha256sum "$CURRENT_APK" | awk '{print $1}')"
    if [ "$CURRENT_APK_SHA" != "$APK_SHA256" ] ||
       ! cmp -s "$CURRENT_MANIFEST" "$REMOTE_MANIFEST_TMP" ||
       ! cmp -s "$CURRENT_SIGNATURE" "$REMOTE_SIG_TMP"; then
      echo "Refusing to replace an existing build number with different release bytes." >&2
      exit 1
    fi
    echo "This exact SODFA build is already published; no replacement is needed."
    exit 0
  fi
fi

if [ -e "$CURRENT_APK" ]; then
  EXISTING_SHA="$(sha256sum "$CURRENT_APK" | awk '{print $1}')"
  if [ "$EXISTING_SHA" != "$APK_SHA256" ]; then
    echo "Refusing to replace a published APK filename with different bytes." >&2
    exit 1
  fi
fi

mv -- "$REMOTE_APK_TMP" "$CURRENT_APK"
mv -- "$REMOTE_SIG_TMP" "$CURRENT_SIGNATURE"
mv -- "$REMOTE_MANIFEST_TMP" "$CURRENT_MANIFEST"
echo "Published SODFA build $BUILD_NUMBER."
