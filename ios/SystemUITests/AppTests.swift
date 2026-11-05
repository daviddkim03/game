import XCTest

final class AppTests: AppTestCase {
    func testSignInRejectsAWrongPasswordThenLetsYouIn() {
        launch("-signedOut")
        let email = element("signin.email")
        XCTAssertTrue(email.waitForExistence(timeout: 8))
        snapshot("signin")
        email.tap()
        email.typeText("e2e@example.com")
        let password = element("signin.password")
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

    func testSettingsControlAlerts() {
        launch()
        tap("now.settings")
        XCTAssertTrue(element("settings.timesUp").waitForExistence(timeout: 5))
        snapshot("settings")
        let alert = element("settings.alert.gym")
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
    }

    func testSigningOutReturnsToSignIn() {
        launch()
        tap("now.settings")
        XCTAssertTrue(element("settings.timesUp").waitForExistence(timeout: 5))
        app.swipeUp()
        app.swipeUp()
        tap("settings.signOut")
        XCTAssertTrue(element("signin.email").waitForExistence(timeout: 8))
    }

    func testTutoringTab() {
        launch()
        openTab("Tutoring")
        expect("tutoring.total", "Total, $140")
        snapshot("tutoring")
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
        XCTAssertTrue(element("kpi.GAME").waitForExistence(timeout: 8))
        snapshot("dark-budget")
        pick("Spending", in: "budget.page")
        snapshot("dark-spending")
        openTab("Calendar")
        pick("Month", in: "calendar.mode")
        XCTAssertTrue(element("month.2026-11-12").waitForExistence(timeout: 8))
        snapshot("dark-month")
    }
}
