#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/dist/WeChat Chat Exporter.app"
ARCH="${ARCH:-$(uname -m)}"

APP_PATH="$APP" ARCH="$ARCH" "$ROOT/Scripts/make-app.sh"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
NAME="WeChat-Chat-Exporter-$VERSION-macos-$ARCH.dmg"
ARCHIVE="$ROOT/dist/$NAME"
VERIFY_DIR="$(mktemp -d "${TMPDIR:-/tmp}/wechat-package.XXXXXX")"
trap 'rm -rf "$VERIFY_DIR"' EXIT

mkdir -p "$VERIFY_DIR/image"
ditto "$APP" "$VERIFY_DIR/image/WeChat Chat Exporter.app"
ln -s /Applications "$VERIFY_DIR/image/Applications"
hdiutil create -ov -format UDZO -volname "WeChat Chat Exporter $VERSION" \
  -srcfolder "$VERIFY_DIR/image" "$ARCHIVE"
hdiutil verify "$ARCHIVE"
(cd "$ROOT/dist" && shasum -a 256 "$NAME" > "$NAME.sha256")
echo "packaged $ARCHIVE"
echo "Signing and packaging do not imply Apple notarization. Check the signing identity before distribution."
