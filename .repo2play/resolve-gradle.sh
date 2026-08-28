#!/usr/bin/env bash
set -euo pipefail
PROJECT="${1:?}"
OUT="${2:?}"

cd "$PROJECT"

download_gradle() {
  local ver="$1"
  local dir="$RUNNER_TEMP/repo2play-gradle-$ver"
  if [ ! -x "$dir/gradle-$ver/bin/gradle" ]; then
    rm -rf "$dir"; mkdir -p "$dir"
    curl -fsSL --retry 3 "https://services.gradle.org/distributions/gradle-${ver}-bin.zip" -o "$dir/gradle.zip"
    unzip -q "$dir/gradle.zip" -d "$dir"
  fi
  printf '%s\n' "$dir/gradle-$ver/bin/gradle"
}

if [ -f gradlew ]; then
  chmod +x gradlew
  CMD="$PROJECT/gradlew"
  echo "PASS Existing Gradle wrapper"
elif [ -f gradle/wrapper/gradle-wrapper.properties ]; then
  URL="$(grep '^distributionUrl=' gradle/wrapper/gradle-wrapper.properties | cut -d= -f2- | sed 's#\\:#:#g' || true)"
  VER="$(printf '%s' "$URL" | sed -n 's/.*gradle-\([0-9][0-9.]*\)-.*/\1/p')"
  [ -n "$VER" ] || exit 1
  echo "RECOVERY Missing gradlew; using Gradle $VER"
  CMD="$(download_gradle "$VER")"
else
  # General fallback for modern Android projects; build errors are later reported clearly.
  VER="8.9"
  echo "RECOVERY No wrapper metadata; trying Gradle $VER"
  CMD="$(download_gradle "$VER")"
fi

"$CMD" --version
printf 'GRADLE_CMD=%q\n' "$CMD" > "$OUT"
