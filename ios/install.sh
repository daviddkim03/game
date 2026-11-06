#!/bin/bash
# Builds the app and installs it on a paired iPhone. Run it again after pulling
# changes or when the signing runs out.
#   ./install.sh                 uses the first paired iPhone
#   ./install.sh "Some iPhone"   uses that one
# Put the account's email in ios/.account to sign in with just a password, and
# a paid team's settings in ios/.signing.xcconfig. Both stay out of git because
# this repo is public.
set -euo pipefail
cd "$(dirname "$0")"

if [ -f .signing.xcconfig ]; then
  export XCODE_XCCONFIG_FILE="$PWD/.signing.xcconfig"
fi

xcodegen generate --quiet

# Build for the phone itself: a team can't get a signing profile that covers it
# until it's registered, and xcodebuild only registers the one it's building for.
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
  -quiet \
  SYSTEM_ACCOUNT="$(cat .account 2>/dev/null || true)"

xcrun devicectl device install app --device "$device" build/device/Build/Products/Release-iphoneos/System.app
echo "Installed on $device. If iOS says the developer isn't trusted: Settings > General > VPN & Device Management."
