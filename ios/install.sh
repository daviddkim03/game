#!/bin/bash
# Builds the app and installs it on a paired iPhone. Run it again whenever the
# free signing runs out (every 7 days) or after pulling changes.
#   ./install.sh                 uses the first paired iPhone
#   ./install.sh "Some iPhone"   uses that one
set -euo pipefail
cd "$(dirname "$0")"

device="${1:-$(xcrun devicectl list devices 2>/dev/null | grep iPhone | grep -E 'available|connected' | grep -oE '[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}' | head -1)}"
if [ -z "$device" ]; then
  echo "No paired iPhone found. Unlock it and put it on the same Wi-Fi, or plug it in." >&2
  exit 1
fi

xcodegen generate --quiet
xcodebuild build \
  -project System.xcodeproj \
  -scheme System \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/device \
  -allowProvisioningUpdates \
  -quiet

xcrun devicectl device install app --device "$device" build/device/Build/Products/Release-iphoneos/System.app
echo "Installed on $device. If iOS says the developer isn't trusted: Settings > General > VPN & Device Management."
