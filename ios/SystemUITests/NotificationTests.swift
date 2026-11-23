import XCTest

/// Real notifications from the system, not a mock: these wait for iOS to
/// deliver one, then press its buttons from outside the app.
final class NotificationTests: AppTestCase {
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    private var banner: XCUIElement {
        springboard.otherElements["Notification"].firstMatch
    }

    private func launchAllowingAlerts(at time: String = "2026-11-05T09:58", _ arguments: String...) {
        launch(at: time, ["-askAlerts"] + arguments)
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 8) {
            allow.tap()
        }
    }

    func testTheNextAlertIsReallyQueuedOnThePhone() {
        launchAllowingAlerts()
        tap("now.settings")
        // The first alert after 9:58 AM is five minutes before gym at 4:30 PM.
        expect("settings.nextAlert", "Next alert, gym in 5 min, 4:25 PM")
        snapshot("settings-next-alert")
    }

    func testNothingIsQueuedForTheEndOfAThing() {
        // Past gym's alert, with work about to end at 4:30 PM.
        launchAllowingAlerts(at: "2026-11-05T16:27")
        tap("now.settings")
        expect("settings.nextAlert", "Next alert, tutoring in 5 min, 5:55 PM")
    }

    func testSkippingCancelsTheQueuedAlert() {
        launchAllowingAlerts()
        tap("today.gym")
        tap("block.skip")
        tap("now.settings")
        expect("settings.nextAlert", "Next alert, tutoring in 5 min, 5:55 PM")
    }

    func testPlusFifteenMovesTheQueuedAlert() {
        launchAllowingAlerts()
        tap("now.extend")
        tap("now.settings")
        expect("settings.nextAlert", "Next alert, gym in 5 min, 4:40 PM")
    }

    /// Switched off in iPhone Settings, then back on from the app's own link.
    func testBlockedInIPhoneSettingsShowsAWayBack() {
        let iPhoneSettings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        let allowed = iPhoneSettings.switches["Allow Notifications"].firstMatch

        launchAllowingAlerts()
        tap("now.settings")
        expect("settings.nextAlert", "Next alert, gym in 5 min, 4:25 PM")
        XCTAssertFalse(element("settings.allow").exists)

        iPhoneSettings.launch()
        for row in ["Apps", "System", "Notifications"] {
            let link = iPhoneSettings.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", row)).firstMatch
            for _ in 0..<6 where !(link.waitForExistence(timeout: 2) && link.isHittable) { iPhoneSettings.swipeUp() }
            link.tap()
        }
        XCTAssertTrue(allowed.waitForExistence(timeout: 10))
        allowed.switches.firstMatch.tap()
        app.activate()
        XCTAssertTrue(element("settings.allow").waitForExistence(timeout: 8))
        XCTAssertFalse(element("settings.nextAlert").exists)
        snapshot("settings-blocked")

        tap("settings.allow")
        XCTAssertTrue(allowed.waitForExistence(timeout: 10))
        allowed.switches.firstMatch.tap()
        app.activate()
        expect("settings.nextAlert", "Next alert, gym in 5 min, 4:25 PM")
        XCTAssertFalse(element("settings.allow").exists)
    }

    /// The notification's "+15 min" button lengthens work with the app closed.
    func testTheAlertArrivesAndItsButtonWorks() {
        launchAllowingAlerts(at: "2026-11-05T16:24")
        expect("now.ends", "Ends 4:30 PM")
        XCUIDevice.shared.press(.home)

        XCTAssertTrue(banner.waitForExistence(timeout: 90), "The alert never arrived")
        snapshot("notification-banner")
        banner.press(forDuration: 1.2)

        let extend = springboard.buttons["+15 min"]
        XCTAssertTrue(extend.waitForExistence(timeout: 8), "No +15 min button on the alert")
        XCTAssertTrue(springboard.buttons["Skip today"].exists)
        snapshot("notification-actions")
        extend.tap()

        app.activate()
        expect("now.ends", "Ends 4:45 PM")
    }

    /// Skipping only the first block would leave an alert for the second.
    func testSkippingFromTheAlertSkipsEveryBlockOfTheThing() {
        launchAllowingAlerts(at: "2026-11-05T16:24", "-splitGym")
        expect("now.next", "Next: gym at 4:30 PM")
        XCUIDevice.shared.press(.home)

        XCTAssertTrue(banner.waitForExistence(timeout: 90), "The alert never arrived")
        banner.press(forDuration: 1.2)
        let skip = springboard.buttons["Skip today"]
        XCTAssertTrue(skip.waitForExistence(timeout: 8), "No Skip today button on the alert")
        skip.tap()

        app.activate()
        expect("now.next", "Next: tutoring at 6:00 PM")
        tap("now.settings")
        expect("settings.nextAlert", "Next alert, tutoring in 5 min, 5:55 PM")
    }

    /// The same alert, with notifications turned off before it's due.
    func testNothingArrivesWhileNotificationsAreOff() {
        launchAllowingAlerts(at: "2026-11-05T16:24")
        tap("now.settings")
        expect("settings.nextAlert", "Next alert, gym in 5 min, 4:25 PM")
        flip("settings.notifications")
        XCTAssertTrue(element("settings.nextAlert").waitForNonExistence(timeout: 8))
        XCUIDevice.shared.press(.home)
        XCTAssertFalse(banner.waitForExistence(timeout: 90), "An alert arrived with notifications off")

        app.activate()
        flip("settings.notifications")
        expect("settings.nextAlert", "Next alert, tutoring in 5 min, 5:55 PM")
    }
}
