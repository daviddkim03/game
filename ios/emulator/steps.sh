#!/bin/bash
# The body of run.sh, with the emulators already up.
set -euo pipefail
AUTH=http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/projects/demo-system/accounts

for account in "emulator-owner owner@example.com" "emulator-stranger stranger@example.com"; do
  read -r uid email <<<"$account"
  curl -sf -X POST "$AUTH" -H "Authorization: Bearer owner" -H "Content-Type: application/json" \
    -d "{\"localId\":\"$uid\",\"email\":\"$email\",\"password\":\"emulator-only\"}" >/dev/null
done

node web-sync.mjs seed
(cd ../SystemCore && FIREBASE_EMULATOR=1 swift test --filter FirebaseEmulatorTests)
node web-sync.mjs verify
