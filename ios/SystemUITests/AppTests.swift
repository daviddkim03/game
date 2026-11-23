import XCTest

final class AppTests: AppTestCase {
    func testSignInRejectsAWrongPasswordThenLetsYouIn() {
        launch("-signedOut")
        let password = element("signin.password")
        XCTAssertTrue(password.waitForExistence(timeout: 8))
        XCTAssertFalse(element("signin.email").exists)
        snapshot("signin")
        password.tap()
        password.typeText("wrong")
        tap("signin.submit")
        XCTAssertTrue(element("signin.error").waitForExistence(timeout: 5))
        password.tap()
        password.typeText(
            XCUIKeyboardKey.delete.rawValue + XCUIKeyboardKey.delete.rawValue + XCUIKeyboardKey.delete.rawValue
                + XCUIKeyboardKey.delete.rawValue + XCUIKeyboardKey.delete.rawValue)
        password.typeText("password")
        tap("signin.submit")
        expect("now.label", "work")
    }

    func testABuildWithNoAccountAsksForTheEmail() {
        launch("-signedOut", "-noAccount")
        let email = element("signin.email")
        XCTAssertTrue(email.waitForExistence(timeout: 8))
        XCTAssertFalse(element("signin.submit").isEnabled)
        element("signin.password").tap()
        element("signin.password").typeText("password")
        XCTAssertFalse(element("signin.submit").isEnabled)
        email.tap()
        email.typeText("e2e@example.com")
        tap("signin.submit")
        expect("now.label", "work")
    }

    func testOneSwitchTurnsNotificationsOffAndOn() {
        launch()
        tap("now.settings")
        let gym = element("settings.alert.gym")
        XCTAssertTrue(gym.waitForExistence(timeout: 5))
        snapshot("settings")

        flip("settings.notifications")
        XCTAssertTrue(gym.waitForNonExistence(timeout: 5))
        snapshot("settings-off")

        // It stays off after leaving and coming back.
        app.buttons["Done"].tap()
        tap("now.settings")
        XCTAssertTrue(app.switches["settings.notifications"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.switches["settings.notifications"].value as? String, "0")
        XCTAssertFalse(gym.exists)

        flip("settings.notifications")
        XCTAssertTrue(gym.waitForExistence(timeout: 5))
    }

    func testSigningOutReturnsToSignIn() {
        launch()
        tap("now.settings")
        XCTAssertTrue(element("settings.notifications").waitForExistence(timeout: 5))
        app.swipeUp()
        app.swipeUp()
        tap("settings.signOut")
        XCTAssertTrue(element("signin.password").waitForExistence(timeout: 8))
    }

    func testTheTabsAreNowCalendarAndBudget() {
        launch()
        expect("now.label", "work")
        XCTAssertEqual(app.tabBars.buttons.allElementsBoundByIndex.map(\.label), ["Now", "Calendar", "Budget"])
        snapshot("tabs")
    }

    /// Run with the simulator in dark mode: `xcrun simctl ui ... appearance dark`.
    func testDarkModeScreens() {
        launch()
        expect("now.label", "work")
        snapshot("dark-now")
        openTab("Calendar")
        XCTAssertTrue(element("tile.2026-11-05.work").waitForExistence(timeout: 8))
        snapshot("dark-calendar")
        openTab("Budget")
        XCTAssertTrue(element("overview.game").waitForExistence(timeout: 8))
        snapshot("dark-budget")
        openTab("Calendar")
        pick("Month", in: "calendar.mode")
        XCTAssertTrue(element("month.2026-11-12").waitForExistence(timeout: 8))
        snapshot("dark-month")
    }
}
