#!/usr/bin/env bash
set -uo pipefail

TARGET="${1:?target path required}"
OUTPUT="${2:?output path required}"
ENGINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

rm -rf "$OUTPUT"
mkdir -p "$OUTPUT"

REPORT="$OUTPUT/BUILD-REPORT.txt"
{
  echo "REPO2PLAY V11 PRODUCTION STAGE 1"
  echo "============================"
  echo "Repository: ${TARGET_REPOSITORY:-unknown}"
  echo "Branch: ${TARGET_BRANCH:-unknown}"
  echo "Mode: ${BUILD_MODE:-NEW}"
  echo "Started: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  echo
} > "$REPORT"

fail_report() {
  local msg="$1"
  {
    echo
    echo "FINAL RESULT: BLOCKED"
    echo "Reason: $msg"
  } >> "$REPORT"
  echo "$msg" > "$OUTPUT/ERROR.txt"
  exit 1
}

DETECT_OUT="$OUTPUT/detect.env"
"$ENGINE/scripts/detect-project.sh" "$TARGET" "$DETECT_OUT" >> "$REPORT" 2>&1 || fail_report "Android application project could not be detected."
source "$DETECT_OUT"

python3 "$ENGINE/scripts/version.py" "$PROJECT_DIR" "$APP_MODULE" "${BUILD_MODE:-NEW}" "$OUTPUT/VERSION-INFO.json" >> "$REPORT" 2>&1 || fail_report "Version preparation failed."

GRADLE_OUT="$OUTPUT/gradle.env"
"$ENGINE/scripts/resolve-gradle.sh" "$PROJECT_DIR" "$GRADLE_OUT" >> "$REPORT" 2>&1 || fail_report "Compatible Gradle could not be prepared."
source "$GRADLE_OUT"

"$ENGINE/scripts/build.sh" "$PROJECT_DIR" "$GRADLE_CMD" "$APP_MODULE" "$OUTPUT" >> "$REPORT" 2>&1 || fail_report "Android release build failed."

"$ENGINE/scripts/sign.sh" "$OUTPUT" >> "$REPORT" 2>&1 || fail_report "Signing failed."

"$ENGINE/scripts/doctor.sh" "$PROJECT_DIR" "$OUTPUT" >> "$REPORT" 2>&1 || true
"$ENGINE/scripts/package.sh" "$OUTPUT" >> "$REPORT" 2>&1 || fail_report "Final package preparation failed."

{
  echo
  echo "FINAL RESULT: SUCCESS"
  echo "Finished: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
} >> "$REPORT"

echo "Repo2Play completed successfully."
