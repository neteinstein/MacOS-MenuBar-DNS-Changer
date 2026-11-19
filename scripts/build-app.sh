#!/usr/bin/env bash
# Builds build/PrivateDNS.app (universal: Apple silicon + Intel) and build/PrivateDNS.zip.
#
# Without signing variables the app is ad-hoc signed and switches DNS with configuration profiles.
# For one-click switching (Network Extension), sign it with the dns-settings entitlement:
#
#   SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
#   TEAM_ID=TEAMID \
#   PROVISIONING_PROFILE=/path/to/PrivateDNS.provisionprofile \
#   BUNDLE_ID=org.example.privatedns \
#   ./scripts/build-app.sh
#
# Other variables: VERSION (default 0.1.0), BUILD (default 1), ARCHS (default "arm64 x86_64").
set -euo pipefail

cd "$(dirname "$0")/.."

BUNDLE_ID="${BUNDLE_ID:-org.neteinstein.privatedns.menubar}"
VERSION="${VERSION:-0.1.0}"
BUILD="${BUILD:-1}"
ARCHS="${ARCHS:-arm64 x86_64}"
APP="build/PrivateDNS.app"

arch_flags=()
for arch in $ARCHS; do arch_flags+=(--arch "$arch"); done

swift build -c release "${arch_flags[@]}"
BIN_DIR="$(swift build -c release "${arch_flags[@]}" --show-bin-path)"

rm -rf "$APP" build/PrivateDNS.zip
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/PrivateDNSMenuBar" "$APP/Contents/MacOS/PrivateDNSMenuBar"
sed -e "s/__BUNDLE_ID__/$BUNDLE_ID/g" -e "s/__VERSION__/$VERSION/g" -e "s/__BUILD__/$BUILD/g" \
  Resources/Info.plist > "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist"

if [[ -n "${SIGN_IDENTITY:-}" && -n "${PROVISIONING_PROFILE:-}" ]]; then
  : "${TEAM_ID:?TEAM_ID is required when signing with a provisioning profile}"
  cp "$PROVISIONING_PROFILE" "$APP/Contents/embedded.provisionprofile"
  ENTITLEMENTS="$(mktemp -t privatedns-entitlements).plist"
  sed -e "s/__TEAM_ID__/$TEAM_ID/g" -e "s/__BUNDLE_ID__/$BUNDLE_ID/g" Resources/PrivateDNS.entitlements > "$ENTITLEMENTS"
  codesign --force --options runtime --timestamp --entitlements "$ENTITLEMENTS" --sign "$SIGN_IDENTITY" "$APP"
  echo "Signed with the Network Extension entitlement: switching uses NEDNSSettingsManager."
else
  codesign --force --sign - "$APP"
  echo "Ad-hoc signed (no entitlements): switching uses configuration profiles."
fi
codesign --verify --strict --verbose=2 "$APP"

ditto -c -k --keepParent "$APP" build/PrivateDNS.zip
echo "Built $APP and build/PrivateDNS.zip"
