#!/usr/bin/env bash
set -euo pipefail
PROJECT="${1:?}"
OUTPUT="${2:?}"
R="$OUTPUT/PLAY-REPORT.txt"

{
  echo "REPO2PLAY V11 PLAY STORE DOCTOR"
  echo "==============================="
  echo

  if find "$PROJECT" -type f -name AndroidManifest.xml ! -path '*/build/*' | grep -q .; then
    echo "PASS AndroidManifest found"
  else
    echo "WARNING AndroidManifest not found"
  fi

  TARGET="$(grep -RhoE 'targetSdk(Version)?[[:space:]=()]+[0-9]+' "$PROJECT" --include='*.gradle' --include='*.gradle.kts' 2>/dev/null | grep -oE '[0-9]+' | sort -nr | head -1 || true)"
  COMPILE="$(grep -RhoE 'compileSdk(Version)?[[:space:]=()]+[0-9]+' "$PROJECT" --include='*.gradle' --include='*.gradle.kts' 2>/dev/null | grep -oE '[0-9]+' | sort -nr | head -1 || true)"

  echo "Detected targetSdk: ${TARGET:-unknown}"
  echo "Detected compileSdk: ${COMPILE:-unknown}"

  # Google Play mobile policy baseline for new apps and updates from 2026-08-31.
  if [ "${TARGET:-0}" -ge 36 ] 2>/dev/null; then
    echo "PASS targetSdk meets API 36 mobile submission baseline"
  else
    echo "WARNING targetSdk does not meet API 36 mobile submission baseline effective 2026-08-31"
  fi

  if [ "${COMPILE:-0}" -ge 36 ] 2>/dev/null; then
    echo "PASS compileSdk >= 36"
  else
    echo "WARNING compileSdk below 36 or not detected"
  fi

  if grep -R -q 'android:debuggable="true"' "$PROJECT" --include='AndroidManifest.xml' 2>/dev/null; then
    echo "WARNING debuggable=true detected"
  else
    echo "PASS no explicit debuggable=true"
  fi

  if grep -R -q 'android:usesCleartextTraffic="true"' "$PROJECT" --include='AndroidManifest.xml' 2>/dev/null; then
    echo "WARNING cleartext traffic explicitly enabled"
  else
    echo "PASS no explicit cleartext traffic enablement"
  fi

  EXPORTED="$(grep -Rho 'android:exported="true"' "$PROJECT" --include='AndroidManifest.xml' 2>/dev/null | wc -l | tr -d ' ')"
  echo "INFO exported=true components: ${EXPORTED:-0}"

  if [ -f "$OUTPUT/app-release-signed.apk" ]; then
    echo "PASS signed APK present"
  else
    echo "BLOCKER signed APK missing"
  fi

  if [ -f "$OUTPUT/app-release-signed.aab" ]; then
    echo "PASS signed AAB present"
  else
    echo "BLOCKER signed AAB missing"
  fi

  echo
  echo "POLICY NOTE"
  echo "Starting 2026-08-31, new mobile apps and app updates submitted to Google Play must target Android 16 / API 36 or higher."
  echo "This is a technical preflight, not a guarantee of Google Play approval."
} > "$R"

cat "$R"
