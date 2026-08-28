#!/usr/bin/env bash
set -euo pipefail
TARGET="${1:?}"
OUT="${2:?}"

SETTINGS="$(find "$TARGET" -type f \( -name settings.gradle -o -name settings.gradle.kts \) ! -path '*/build/*' | head -1 || true)"
[ -n "$SETTINGS" ] || { echo "No settings.gradle/settings.gradle.kts"; exit 1; }
PROJECT_DIR="$(dirname "$SETTINGS")"

APP_BUILD=""
while IFS= read -r f; do
  if grep -Eq 'com\.android\.application|id[[:space:]]*\(?[[:space:]]*["'\'']com\.android\.application|apply plugin:[[:space:]]*["'\'']com\.android\.application' "$f"; then
    APP_BUILD="$f"; break
  fi
done < <(find "$PROJECT_DIR" -type f \( -name build.gradle -o -name build.gradle.kts \) ! -path '*/build/*')

[ -n "$APP_BUILD" ] || { echo "No com.android.application module found"; exit 1; }
MODULE_DIR="$(dirname "$APP_BUILD")"
REL="${MODULE_DIR#"$PROJECT_DIR"/}"
if [ "$MODULE_DIR" = "$PROJECT_DIR" ]; then
  APP_MODULE=""
else
  APP_MODULE="${REL//\//:}"
fi

{
  printf 'PROJECT_DIR=%q\n' "$PROJECT_DIR"
  printf 'APP_MODULE=%q\n' "$APP_MODULE"
} > "$OUT"

echo "PASS Android project: $PROJECT_DIR"
echo "PASS Application module: ${APP_MODULE:-root}"
