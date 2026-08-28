#!/usr/bin/env bash
set -euo pipefail
OUTPUT="${1:?}"

[ -f "$OUTPUT/app-release-signed.apk" ] || { echo "Signed APK missing"; exit 1; }
[ -f "$OUTPUT/app-release-signed.aab" ] || { echo "Signed AAB missing"; exit 1; }
[ -f "$OUTPUT/SIGNING-INFO.txt" ] || { echo "Signing report missing"; exit 1; }

rm -f "$OUTPUT/app-release-unsigned.apk" "$OUTPUT/app-release-aligned.apk" "$OUTPUT/app-release-unsigned.aab" "$OUTPUT/detect.env" "$OUTPUT/gradle.env"

(
  cd "$OUTPUT"
  sha256sum app-release-signed.apk app-release-signed.aab > SHA256SUMS.txt
)

echo "PASS Final signed APK/AAB package prepared"
