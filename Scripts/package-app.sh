#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/dist/WeChat Chat Exporter.app"
ARCH="${ARCH:-$(uname -m)}"

APP_PATH="$APP" ARCH="$ARCH" "$ROOT/Scripts/make-app.sh"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
NAME="WeChat-Chat-Exporter-$VERSION-macos-$ARCH.zip"
ARCHIVE="$ROOT/dist/$NAME"
VERIFY_DIR="$(mktemp -d "${TMPDIR:-/tmp}/wechat-package.XXXXXX")"
trap 'rm -rf "$VERIFY_DIR"' EXIT

ditto -c -k --sequesterRsrc --keepParent "$APP" "$ARCHIVE"
ditto -x -k "$ARCHIVE" "$VERIFY_DIR"
codesign --verify --deep --strict "$VERIFY_DIR/WeChat Chat Exporter.app"
(cd "$ROOT/dist" && shasum -a 256 "$NAME" > "$NAME.sha256")
echo "packaged $ARCHIVE"
echo "Signing and packaging do not imply Apple notarization. Check the signing identity before distribution."
