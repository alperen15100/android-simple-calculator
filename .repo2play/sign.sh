#!/usr/bin/env bash
set -euo pipefail

OUTPUT="${1:?}"
MODE="${BUILD_MODE:-NEW}"
KEYSTORE="$OUTPUT/repo2play-upload.jks"
ALIAS="${SIGNING_KEY_ALIAS:-repo2play}"
STOREPASS="${SIGNING_STORE_PASSWORD:-Repo2Play123!}"
KEYPASS="${SIGNING_KEY_PASSWORD:-Repo2Play123!}"

if [ "$MODE" = "UPDATE" ]; then
  [ -n "${APP_KEYSTORE_BASE64:-}" ] || { echo "UPDATE mode requires APP_KEYSTORE_BASE64"; exit 1; }
  printf '%s' "$APP_KEYSTORE_BASE64" | base64 --decode > "$KEYSTORE"
  [ -s "$KEYSTORE" ] || { echo "Decoded keystore is empty"; exit 1; }
  echo "PASS Existing keystore loaded for UPDATE"
else
  keytool -genkeypair \
    -keystore "$KEYSTORE" \
    -storepass "$STOREPASS" \
    -keypass "$KEYPASS" \
    -alias "$ALIAS" \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -dname "CN=Repo2Play, OU=Android, O=Repo2Play, L=Unknown, ST=Unknown, C=US" \
    >/dev/null 2>&1
  echo "PASS New keystore generated"
fi

BUILD_TOOLS="$(find "$ANDROID_HOME/build-tools" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -1)"
[ -n "$BUILD_TOOLS" ] || { echo "Android build-tools not found"; exit 1; }

ZIPALIGN="$BUILD_TOOLS/zipalign"
APKSIGNER="$BUILD_TOOLS/apksigner"

[ -x "$ZIPALIGN" ] || { echo "zipalign not found"; exit 1; }
[ -x "$APKSIGNER" ] || { echo "apksigner not found"; exit 1; }

"$ZIPALIGN" -f 4 "$OUTPUT/app-release-unsigned.apk" "$OUTPUT/app-release-aligned.apk"

"$APKSIGNER" sign \
  --ks "$KEYSTORE" \
  --ks-key-alias "$ALIAS" \
  --ks-pass "pass:$STOREPASS" \
  --key-pass "pass:$KEYPASS" \
  --out "$OUTPUT/app-release-signed.apk" \
  "$OUTPUT/app-release-aligned.apk"

"$APKSIGNER" verify --verbose "$OUTPUT/app-release-signed.apk" >/dev/null
echo "PASS APK signature VERIFIED"

cp "$OUTPUT/app-release-unsigned.aab" "$OUTPUT/app-release-signed.aab"

jarsigner \
  -sigalg SHA256withRSA \
  -digestalg SHA-256 \
  -keystore "$KEYSTORE" \
  -storepass "$STOREPASS" \
  -keypass "$KEYPASS" \
  "$OUTPUT/app-release-signed.aab" \
  "$ALIAS" \
  >/dev/null

jarsigner -verify "$OUTPUT/app-release-signed.aab" >/dev/null
echo "PASS AAB signature VERIFIED"

{
  echo "REPO2PLAY SIGNING INFO"
  echo "======================"
  echo "Mode: $MODE"
  echo "Alias: $ALIAS"
  keytool -list -v -keystore "$KEYSTORE" -storepass "$STOREPASS" -alias "$ALIAS" \
    | grep -E 'SHA1:|SHA256:' || true
} > "$OUTPUT/SIGNING-INFO.txt"

if [ "$MODE" = "NEW" ]; then
  {
    echo "IMPORTANT"
    echo "========="
    echo "Keep repo2play-upload.jks, alias and passwords safe."
    echo "You need the same signing identity for future updates outside Play App Signing workflows."
  } >> "$OUTPUT/SIGNING-INFO.txt"
fi
