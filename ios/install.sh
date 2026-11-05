#!/bin/bash
# Builds the app and installs it on a paired iPhone. Run it again whenever the
# free signing runs out (every 7 days) or after pulling changes.
#   ./install.sh                 uses the first paired iPhone
#   ./install.sh "Some iPhone"   uses that one
set -euo pipefail
cd "$(dirname "$0")"

xcodegen generate --quiet

# Build for the phone itself: a free team can't get a signing profile until a
# device is registered, and xcodebuild only registers the one it's building for.
device="$(xcodebuild -showdestinations -project System.xcodeproj -scheme System 2>/dev/null |
  grep 'platform:iOS, arch:' | grep -v 'error:' | grep -F "name:${1:-}" |
  sed -E 's/.*id:([^,]+),.*/\1/' | head -1 || true)"
if [ -z "$device" ]; then
  echo "No paired iPhone found. Unlock it and put it on the same Wi-Fi, or plug it in." >&2
  exit 1
fi

xcodebuild build \
  -project System.xcodeproj \
  -scheme System \
  -configuration Release \
  -destination "id=$device" \
  -derivedDataPath build/device \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  -quiet

xcrun devicectl device install app --device "$device" build/device/Build/Products/Release-iphoneos/System.app
echo "Installed on $device. If iOS says the developer isn't trusted: Settings > General > VPN & Device Management."
