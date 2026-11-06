# System for iOS

The phone version of the tools in this repo: a native SwiftUI app using the same Firebase data as the website, so edits on either side show up on the other.

- **Now**: what's happening, when it ends, what's next, and +15 min or Skip today.
- **Calendar**: day, week, month, and year views of the weekly schedule.
- **Budget**: how much you're playing with, plus income, expenses, and the bill calendar.

The app doesn't track spending, and the payment report stays on the website.

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

## Widgets

The Now widget comes in small and medium for the home screen, plus rectangular and inline for the Lock Screen. The app leaves the schedule and today's changes in a shared app group (`WidgetStore`), and the widget works out the time itself with the same `dayPlan` code, so it stays right without the app running. `SystemWidget` needs its own App ID under the app's, so signing it takes an Apple ID in Xcode.

## Installing on a phone

Add your Apple ID once in Xcode > Settings > Accounts. Then, with the phone unlocked and on the same Wi-Fi as the Mac (or plugged in):

```sh
./install.sh
```

After the first install, trust the developer on the phone in Settings > General > VPN & Device Management.

To sign in with just a password, put the account's email in `ios/.account`, which git ignores because this repo is public. Without that file, the app asks for the email too.

By default the project signs with a free personal team, so the app stops opening after 7 days until it's installed again. A paid team's build lasts up to a year. A bundle ID belongs to one team for good, so a paid team needs its own, and the widget, app group, and background task IDs are all built from it. Put both in `ios/.signing.xcconfig`, which git also ignores:

```
DEVELOPMENT_TEAM = ABCDE12345
SYSTEM_BUNDLE_ID = com.example.system
```

`install.sh` applies that file to the build. Delete it to go back to the free team.

## Playing with

The Overview's big number is the website's GAME: take-home minus every categorized expense, so the two always agree. Below it, `monthProgress` shows how much of that has landed this month. Paychecks cover the whole month's expenses first, so it stays at $0 until they have, then reaches the full amount with the last payday. It says nothing about the bank balance, which the app doesn't know.

## How data is stored

The app talks to Firebase's REST APIs directly (`FirebaseBackend`), so there's no SDK to update and no Firebase console setup. Every document goes through the same security rules as the website.

The website keeps owning its documents. The app adds one of its own in the same collection: `main_phone` (today-only changes and alert choices). A save only lands if nobody else saved since this device last looked; otherwise the edit is redone on the newer copy, so changes on the PC are never overwritten.

Alerts are scheduled on the phone with no server. iOS keeps at most 64 pending alerts per app, so the app refills them whenever it opens or refreshes in the background. The last slot is a reminder to open the app, so alerts never just go quiet.
