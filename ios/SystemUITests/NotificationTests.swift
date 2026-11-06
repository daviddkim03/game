import XCTest

/// Real notifications from the system, not a mock: these wait for iOS to
/// deliver one, then press its buttons from outside the app.
final class NotificationTests: AppTestCase {
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    /// A Thursday at 9:58 AM that's still to come. iOS drops alerts whose real
    /// time has passed, so these can't pin the clock to a date in the past.
    private var comingThursday: String {
        let calendar = Calendar.current
        let nextWeek = calendar.date(byAdding: .day, value: 7, to: Date())!
        let thursday = calendar.nextDate(after: nextWeek, matching: DateComponents(weekday: 5), matchingPolicy: .nextTime)!
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: thursday) + "T09:58"
    }

    private func launchAllowingAlerts() {
        launch(at: comingThursday, "-askAlerts", "-testAlert")
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
}
