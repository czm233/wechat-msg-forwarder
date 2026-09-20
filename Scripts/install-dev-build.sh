#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT/dist/WeChat Chat Exporter.app"
DESTINATION="${INSTALL_DIR:-$HOME/Applications}/WeChat Chat Exporter.app"

"$ROOT/Scripts/make-app.sh"
mkdir -p "$(dirname "$DESTINATION")"
rm -rf "$DESTINATION"
ditto "$SOURCE" "$DESTINATION"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DESTINATION"
pluginkit -a "$DESTINATION/Contents/PlugIns/WeChatChatExporterShare.appex"
APP_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$DESTINATION/Contents/Info.plist")"
pluginkit -e use -i "$APP_ID.Share"
echo "installed $DESTINATION"
