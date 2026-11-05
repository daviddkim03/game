# System for iOS

The phone version of the tools in this repo: a native SwiftUI app using the same Firebase data as the website, so edits on either side show up on the other.

- **Now**: what's happening, when it ends, what's next, and +15 min or Skip today.
- **Calendar**: day, week, month, and year views of the weekly schedule.
- **Budget**: overview, income, expenses, bill calendar, and spending.
- **Tutoring**: students and sessions from the payment report.

## Layout

| Path          | What it is                                                                   |
| ------------- | ---------------------------------------------------------------------------- |
| `SystemCore/` | Models, money math, alert planning, and sync. No UI, so it tests on the Mac. |
| `System/`     | The SwiftUI app.                                                             |
| `SystemUITests/` | End-to-end tests against made-up data (`-e2e`).                            |
| `emulator/`   | Firebase client tests against local emulators, with the website's SDK.       |

`project.yml` generates the Xcode project, which isn't committed: `xcodegen generate`.

## Tests

```sh
swift test --package-path SystemCore    # models, sync, and parity with the website
./emulator/run.sh                       # the real REST client against Firebase emulators
xcodebuild test -project System.xcodeproj -scheme System \
  -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO
```

`SystemCore/Tests/SystemCoreTests/Fixtures/parity.json` is the output of the website's own TypeScript on made-up data, and the Swift tests must match it exactly. Regenerate it if the money math changes on the site.

## Installing on a phone

Add your Apple ID once in Xcode > Settings > Accounts. Then, with the phone unlocked and on the same Wi-Fi as the Mac (or plugged in):

```sh
./install.sh
```

After the first install, trust the developer on the phone in Settings > General > VPN & Device Management.

The project signs with a free personal team, so the app stops opening after 7 days until it's installed again. Changing `DEVELOPMENT_TEAM` in `project.yml` to a paid team removes that limit.

## How data is stored

The app talks to Firebase's REST APIs directly (`FirebaseBackend`), so there's no SDK to update and no Firebase console setup. Every document goes through the same security rules as the website.

The website keeps owning its documents. The app adds two kinds of its own in the same collection: `main_phone` (today-only changes, alert choices, merchant categories) and `main_spending_YYYY_MM` (one per month). A save only lands if nobody else saved since this device last looked; otherwise the edit is redone on the newer copy, so changes on the PC are never overwritten.

Alerts are scheduled on the phone with no server. iOS keeps at most 64 pending alerts per app, so the app refills them whenever it opens or refreshes in the background. The last slot is a reminder to open the app, so alerts never just go quiet.
