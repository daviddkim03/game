import XCTest

/// The real widgets on the real home and Lock Screens, added the way a person
/// would. They run on the real clock, so a block is put on at the current time.
final class WidgetTests: AppTestCase {
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    /// Returns what the Now screen says, which the widgets have to match.
    private func launchWithSomethingOnNow() throws -> (ends: String, next: String) {
        let hour = Calendar.current.component(.hour, from: Date())
        try XCTSkipIf(hour < 6 || hour >= 22, "The schedule grid has no room for a block at this hour.")
        app = XCUIApplication()
        app.launchArguments = ["-e2e", "-nowBlock"]
        app.launch()
        expect("now.label", "focus")
        let shown = (ends: element("now.ends").label, next: element("now.next").label)
        // The app waits a moment before saving what the widget reads.
        Thread.sleep(forTimeInterval: 1)
        return shown
    }

    func testTheHomeScreenWidgetFollowsTheApp() throws {
        let shown = try launchWithSomethingOnNow()
        XCUIDevice.shared.press(.home)
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.82)).press(forDuration: 1.6)
        XCTAssertTrue(springboard.buttons["Edit"].waitForExistence(timeout: 8))
        addHomeScreenWidget(size: "Small")
        addHomeScreenWidget(size: "Medium")
        springboard.buttons["Done"].tap()

        // One of each size, both showing what's on now.
        XCTAssertTrue(text("focus").waitForExistence(timeout: 15))
        expectOnScreen("focus", count: 2)
        expectOnScreen(shown.ends, count: 2)
        expectOnScreen(shown.next, count: 1)
        expectOnScreen("review", count: 1)
        snapshot("widget-home")

        // Skipping in the app has to reach the widget.
        app.activate()
        tap("now.skip")
        Thread.sleep(forTimeInterval: 1)
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(text("Free").waitForExistence(timeout: 20))
        expectOnScreen("Free", count: 2)
        expectOnScreen("focus", count: 0)
        snapshot("widget-free")

        // So does signing out: the schedule shouldn't stay on the home screen.
        app.activate()
        tap("now.settings")
        XCTAssertTrue(element("settings.timesUp").waitForExistence(timeout: 5))
        app.swipeUp()
        app.swipeUp()
        tap("settings.signOut")
        XCTAssertTrue(element("signin.password").waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 1)
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(text("Open the app to sign in").waitForExistence(timeout: 20))
        expectOnScreen("Free", count: 0)
        snapshot("widget-signed-out")
    }

    func testTheLockScreenWidgetShowsWhatsOnNow() throws {
        let shown = try launchWithSomethingOnNow()
        XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
        Thread.sleep(forTimeInterval: 2)
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 2)
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6)).press(forDuration: 2.5)
        let customize = springboard.buttons["Customize"].firstMatch
        XCTAssertTrue(customize.waitForExistence(timeout: 8))
        customize.tap()

        // Below the clock.
        let slot = springboard.buttons.matching(identifier: "grouped-widgets-reticle-view").firstMatch
        XCTAssertTrue(slot.waitForExistence(timeout: 8))
        slot.tap()
        let system = springboard.cells["System"].firstMatch
        XCTAssertTrue(springboard.cells["Maps"].firstMatch.waitForExistence(timeout: 8))
        for _ in 0..<6 where !system.isHittable {
            springboard.cells["Maps"].firstMatch.swipeUp()
            Thread.sleep(forTimeInterval: 1)
        }
        system.tap()
        let widget = springboard.buttons["System, Now"].firstMatch
        XCTAssertTrue(widget.waitForExistence(timeout: 8))
        XCTAssertEqual(widget.value as? String, "Widget, Rectangular")
        widget.tap()
        Thread.sleep(forTimeInterval: 2)
        snapshot("widget-lock-editing")
        springboard.buttons["close"].firstMatch.tap()
        Thread.sleep(forTimeInterval: 1)
        springboard.buttons["Sheet Grabber"].firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.99)))
        Thread.sleep(forTimeInterval: 2)

        let done = springboard.buttons.matching(identifier: "editing-done").firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        Thread.sleep(forTimeInterval: 3)
        springboard.cells.matching(NSPredicate(format: "identifier BEGINSWITH 'posterboard-posteruuid'")).firstMatch.tap()
        XCTAssertTrue(text("focus").waitForExistence(timeout: 10))
        expectOnScreen(shown.ends, count: 1)
        expectOnScreen(shown.next, count: 1)
        snapshot("widget-lock")
    }

    private func addHomeScreenWidget(size: String) {
        springboard.buttons["Edit"].tap()
        let add = labelled("Add Widget")
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        let search = springboard.searchFields["Search Widgets"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("System")
        let result = springboard.cells["System"]
        XCTAssertTrue(result.waitForExistence(timeout: 20))
        result.tap()

        let widget = springboard.buttons["System, Now"]
        XCTAssertTrue(widget.waitForExistence(timeout: 8))
        for _ in 0..<3 where widget.value as? String != "Widget, \(size)" {
            widget.swipeLeft()
            Thread.sleep(forTimeInterval: 1)
        }
        XCTAssertEqual(widget.value as? String, "Widget, \(size)")
        let confirm = labelled("Add Widget")
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        Thread.sleep(forTimeInterval: 2)
    }

    private func text(_ label: String) -> XCUIElement {
        springboard.staticTexts[label].firstMatch
    }

    private func expectOnScreen(_ label: String, count: Int, line: UInt = #line) {
        let matches = springboard.staticTexts.matching(NSPredicate(format: "label == %@", label))
        XCTAssertEqual(matches.count, count, label, line: line)
    }

    /// Apple's buttons here start with an icon, so an exact label won't match.
    private func labelled(_ text: String) -> XCUIElement {
        springboard.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }
}
