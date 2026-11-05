import XCTest

/// Real notifications from the system, not a mock: these wait for iOS to
/// deliver one, then press its buttons from outside the app.
final class NotificationTests: AppTestCase {
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    private func launchAllowingAlerts(_ alert: String = "-testAlert") {
        launch(at: "2026-11-05T09:58", "-askAlerts", alert)
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 8) {
            allow.tap()
        }
    }

    func testTheNextAlertIsReallyQueuedOnThePhone() {
        launchAllowingAlerts()
        tap("now.settings")
        let next = element("settings.nextAlert")
        XCTAssertTrue(next.waitForExistence(timeout: 8))
        // The first alert after 9:58 AM is five minutes before gym at 4:30 PM.
        XCTAssertEqual(next.label, "Next alert, gym in 5 min, 4:25 PM")
        snapshot("settings-next-alert")
    }

    func testSkippingCancelsTheQueuedAlert() {
        launchAllowingAlerts()
        tap("today.gym")
        tap("block.skip")
        tap("now.settings")
        let next = element("settings.nextAlert")
        XCTAssertTrue(next.waitForExistence(timeout: 8))
        // gym is gone, so work's end at 4:30 PM comes first.
        XCTAssertEqual(next.label, "Next alert, Time's up: work, 4:30 PM")
    }

    func testPlusFifteenMovesTheQueuedAlert() {
        launchAllowingAlerts()
        tap("now.extend")
        tap("now.settings")
        let next = element("settings.nextAlert")
        XCTAssertTrue(next.waitForExistence(timeout: 8))
        XCTAssertEqual(next.label, "Next alert, gym in 5 min, 4:40 PM")
    }

    /// The notification's "+15 min" button lengthens work with the app closed.
    func testTheAlertArrivesAndItsButtonWorks() {
        launchAllowingAlerts()
        expect("now.ends", "Ends 4:30 PM")
        XCUIDevice.shared.press(.home)

        let banner = springboard.otherElements["Notification"].firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 130), "The alert never arrived")
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

    /// The tutoring alert's "Log session" button opens the session, filled in.
    func testLogSessionButtonOpensThePrefilledSession() {
        launchAllowingAlerts("-testTutoringAlert")
        XCUIDevice.shared.press(.home)

        let banner = springboard.otherElements["Notification"].firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 130), "The alert never arrived")
        banner.press(forDuration: 1.2)
        let log = springboard.buttons["Log session"]
        XCTAssertTrue(log.waitForExistence(timeout: 8))
        log.tap()

        XCTAssertTrue(element("session.save").waitForExistence(timeout: 10))
        tap("session.save")
        expect("tutoring.total", "Total, $220")
    }
}
