#!/usr/bin/env bash
# Builds "build/Private DNS.app".
#
# By default it builds for this Mac's architecture, which only needs the Xcode command line tools.
# UNIVERSAL=1 builds for Apple silicon and Intel (needs full Xcode); the release workflow uses it.
# Any arguments are passed on to `swift build`. The Homebrew formula passes --disable-sandbox,
# since SwiftPM can't sandbox its manifest build inside Homebrew's own build sandbox.
#
# The version comes from Resources/Info.plist (CFBundleShortVersionString / CFBundleVersion).
#
# Without signing variables the app is ad-hoc signed and switches DNS with configuration profiles.
# For one-click switching (Network Extension), sign it with the dns-settings entitlement:
#
#   SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
#   TEAM_ID=TEAMID \
#   PROVISIONING_PROFILE=/path/to/PrivateDNS.provisionprofile \
#   BUNDLE_ID=org.example.privatedns \
#   ./scripts/build-app.sh
set -euo pipefail

cd "$(dirname "$0")/.."

BUNDLE_ID="${BUNDLE_ID:-org.neteinstein.privatedns.menubar}"
APP="build/Private DNS.app"

ARCH_FLAGS=()
if [[ "${UNIVERSAL:-0}" == "1" ]]; then ARCH_FLAGS=(--arch arm64 --arch x86_64); fi

swift build -c release --product PrivateDNSMenuBar ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} "$@"
BIN_DIR="$(swift build -c release --product PrivateDNSMenuBar ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} "$@" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/PrivateDNSMenuBar" "$APP/Contents/MacOS/PrivateDNSMenuBar"
sed -e "s/__BUNDLE_ID__/$BUNDLE_ID/g" Resources/Info.plist > "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist"

if [[ -n "${SIGN_IDENTITY:-}" && -n "${PROVISIONING_PROFILE:-}" ]]; then
  : "${TEAM_ID:?TEAM_ID is required when signing with a provisioning profile}"
  cp "$PROVISIONING_PROFILE" "$APP/Contents/embedded.provisionprofile"
  ENTITLEMENTS="$(mktemp -d)/PrivateDNS.entitlements"
  sed -e "s/__TEAM_ID__/$TEAM_ID/g" -e "s/__BUNDLE_ID__/$BUNDLE_ID/g" Resources/PrivateDNS.entitlements > "$ENTITLEMENTS"
  codesign --force --options runtime --timestamp --entitlements "$ENTITLEMENTS" --sign "$SIGN_IDENTITY" "$APP"
  echo "Signed with the Network Extension entitlement: switching uses NEDNSSettingsManager."
else
  codesign --force --sign - "$APP"
  echo "Ad-hoc signed (no entitlements): switching uses configuration profiles."
fi
codesign --verify --strict --verbose=2 "$APP"
echo "Built $APP"
