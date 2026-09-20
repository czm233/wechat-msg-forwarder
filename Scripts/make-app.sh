#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${CONFIG:-release}"
ARCH="${ARCH:-$(uname -m)}"
APP="${APP_PATH:-$ROOT/dist/WeChat Chat Exporter.app}"
BUILD_ROOT="$ROOT/.build/app-bundle"

select_identity() {
  local found
  for prefix in "Developer ID Application:" "Apple Development:"; do
    found="$(security find-identity -v -p codesigning 2>/dev/null | awk -v p="$prefix" 'index($0,p){print $2;exit}')"
    if [ -n "$found" ]; then printf '%s' "$found"; return; fi
  done
  printf '%s' '-'
}

IDENTITY="${IDENTITY:-$(select_identity)}"
APP_GROUP="${APP_GROUP:-$(/usr/libexec/PlistBuddy -c 'Print :MWCEAppGroupIdentifier' "$ROOT/Resources/Info.plist")}"
APP_ID="${APP_ID:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$ROOT/Resources/Info.plist")}"
SCRATCH="$BUILD_ROOT/$ARCH"

# Resolve the actual signing team before building or replacing the existing app.
# This script supports macOS Team-ID-prefixed groups, without provisioning profiles.
PROBE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/wechat-signing.XXXXXX")"
trap 'rm -rf "$PROBE_DIR"' EXIT
cp /usr/bin/true "$PROBE_DIR/signing-probe"
codesign --force --sign "$IDENTITY" "$PROBE_DIR/signing-probe" >/dev/null 2>&1
SIGNING_TEAM="$(codesign -dv "$PROBE_DIR/signing-probe" 2>&1 | sed -n 's/^TeamIdentifier=//p')"
if [ -z "$SIGNING_TEAM" ] || [ "$SIGNING_TEAM" = "not set" ]; then
  echo "A valid Apple signing identity with a Team ID is required." >&2
  exit 1
fi
case "$APP_GROUP" in
  "$SIGNING_TEAM".*) ;;
  *)
    echo "App Group must begin with the signing Team ID: $SIGNING_TEAM." >&2
    echo "Set APP_GROUP to $SIGNING_TEAM.$APP_ID.shared or select the matching IDENTITY." >&2
    exit 1
    ;;
esac

swift build -c "$CONFIG" --triple "$ARCH-apple-macosx" --scratch-path "$SCRATCH" --product WeChatChatExporter
swift build -c "$CONFIG" --triple "$ARCH-apple-macosx" --scratch-path "$SCRATCH" --product WeChatChatExporterShare
BIN_DIR="$(swift build -c "$CONFIG" --triple "$ARCH-apple-macosx" --scratch-path "$SCRATCH" --show-bin-path)"

if ! nm -u "$BIN_DIR/WeChatChatExporterShare" | grep -Fq '_NSExtensionMain'; then
  echo "share extension is missing NSExtensionMain" >&2
  exit 1
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/PlugIns"
cp "$BIN_DIR/WeChatChatExporter" "$APP/Contents/MacOS/WeChatChatExporter"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $APP_ID" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :MWCEAppGroupIdentifier $APP_GROUP" "$APP/Contents/Info.plist"

APPEX="$APP/Contents/PlugIns/WeChatChatExporterShare.appex"
mkdir -p "$APPEX/Contents/MacOS" "$APPEX/Contents/Resources"
cp "$BIN_DIR/WeChatChatExporterShare" "$APPEX/Contents/MacOS/WeChatChatExporterShare"
cp "$ROOT/Resources/Share-Info.plist" "$APPEX/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APPEX/Contents/Resources/AppIcon.icns"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $APP_ID.Share" "$APPEX/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :MWCEAppGroupIdentifier $APP_GROUP" "$APPEX/Contents/Info.plist"
for lproj in "$ROOT/Resources/ShareLocalizations"/*.lproj; do
  ditto "$lproj" "$APPEX/Contents/Resources/$(basename "$lproj")"
done

mkdir -p "$BUILD_ROOT/entitlements"
cp "$ROOT/Resources/App.entitlements" "$BUILD_ROOT/entitlements/App.entitlements"
cp "$ROOT/Resources/Share.entitlements" "$BUILD_ROOT/entitlements/Share.entitlements"
/usr/libexec/PlistBuddy -c "Set :com.apple.security.application-groups:0 $APP_GROUP" "$BUILD_ROOT/entitlements/App.entitlements"
/usr/libexec/PlistBuddy -c "Set :com.apple.security.application-groups:0 $APP_GROUP" "$BUILD_ROOT/entitlements/Share.entitlements"

codesign --force --sign "$IDENTITY" --entitlements "$BUILD_ROOT/entitlements/Share.entitlements" "$APPEX"
codesign --force --sign "$IDENTITY" --entitlements "$BUILD_ROOT/entitlements/App.entitlements" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "built $APP"
echo "app group $APP_GROUP"
echo "identity $IDENTITY"
