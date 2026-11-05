import XCTest

/// Launches the app against made-up data at a fixed time: Thursday,
/// November 5, 2026, 9:58 AM, in the middle of "work" (8:30 AM - 4:30 PM).
class AppTestCase: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    @discardableResult
    func launch(at time: String = "2026-11-05T09:58", _ arguments: String...) -> XCUIApplication {
        app = XCUIApplication()
        app.launchArguments = ["-e2e", "-nowAt", time] + arguments
        app.launch()
        return app
    }

    func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    func tap(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        let target = element(id)
        XCTAssertTrue(target.waitForExistence(timeout: 8), "\(id) never appeared", file: file, line: line)
        target.tap()
    }

    func text(_ id: String) -> String {
        let target = element(id)
        _ = target.waitForExistence(timeout: 8)
        return target.label
    }

    func expect(_ id: String, _ expected: String, file: StaticString = #filePath, line: UInt = #line) {
        let target = element(id)
        let matched = NSPredicate(format: "label == %@", expected)
        let waiter = expectation(for: matched, evaluatedWith: target)
        if XCTWaiter.wait(for: [waiter], timeout: 8) != .completed {
            XCTFail("\(id) is \"\(target.label)\", expected \"\(expected)\"", file: file, line: line)
        }
    }

    /// Replaces the number in a field: a double tap selects it, as by hand.
    func replaceText(of field: XCUIElement, with text: String) {
        field.tap()
        field.doubleTap()
        field.typeText(text)
    }

    func openTab(_ name: String) {
        app.tabBars.buttons[name].firstMatch.tap()
    }

    func pick(_ segment: String, in id: String) {
        let control = element(id)
        XCTAssertTrue(control.waitForExistence(timeout: 8), "\(id) never appeared")
        control.buttons[segment].firstMatch.tap()
    }

    /// True when `element` is fully on screen, not cut off or scrolled away.
    func isOnScreen(_ element: XCUIElement) -> Bool {
        element.exists && app.windows.firstMatch.frame.contains(element.frame)
    }

    /// Saves a screenshot when a folder is given, so a person can look at it.
    func snapshot(_ name: String) {
        guard let folder = ProcessInfo.processInfo.environment["SHOTS"] else { return }
        let data = XCUIScreen.main.screenshot().pngRepresentation
        try? data.write(to: URL(fileURLWithPath: folder).appendingPathComponent("\(name).png"))
    }
}
