import XCTest

final class CalendarTests: AppTestCase {
    private func openCalendar() {
        launch()
        openTab("Calendar")
    }

    func testDayShowsTodaysBlocksWithTheNowLine() {
        openCalendar()
        XCTAssertTrue(element("tile.2026-11-05.work").waitForExistence(timeout: 8))
        XCTAssertTrue(element("calendar.nowLine").exists)
        XCTAssertTrue(app.navigationBars["Thursday, November 5"].exists)
        snapshot("calendar-day")
    }

    func testTappingTheStripChangesDay() {
        openCalendar()
        tap("strip.2026-11-07")
        XCTAssertTrue(app.navigationBars["Saturday, November 7"].waitForExistence(timeout: 5))
        XCTAssertTrue(element("tile.2026-11-07.errands").waitForExistence(timeout: 8))
    }

    func testSwipingChangesDay() {
        openCalendar()
        XCTAssertTrue(element("tile.2026-11-05.work").waitForExistence(timeout: 8))
        app.swipeLeft()
        XCTAssertTrue(app.navigationBars["Friday, November 6"].waitForExistence(timeout: 5))
        app.swipeRight()
        XCTAssertTrue(app.navigationBars["Thursday, November 5"].waitForExistence(timeout: 5))
    }

    func testWeekShowsEveryDayOnScreen() {
        openCalendar()
        pick("Week", in: "calendar.mode")
        for key in ["2026-11-02", "2026-11-03", "2026-11-04", "2026-11-05", "2026-11-06", "2026-11-07", "2026-11-08"] {
            XCTAssertTrue(element("week.\(key)").waitForExistence(timeout: 5), key)
            XCTAssertTrue(isOnScreen(element("week.\(key)")), "\(key) is off screen")
        }
        XCTAssertTrue(element("tile.2026-11-05.work").waitForExistence(timeout: 5))
        snapshot("calendar-week")
        tap("week.2026-11-07")
        XCTAssertTrue(app.navigationBars["Saturday, November 7"].waitForExistence(timeout: 5))
    }

    func testMonthOpensTheDayYouTap() {
        openCalendar()
        pick("Month", in: "calendar.mode")
        XCTAssertTrue(element("month.2026-11-12").waitForExistence(timeout: 8))
        snapshot("calendar-month")
        tap("month.2026-11-12")
        XCTAssertTrue(app.navigationBars["Thursday, November 12"].waitForExistence(timeout: 5))
    }

    func testYearOpensTheMonthYouTap() {
        openCalendar()
        pick("Year", in: "calendar.mode")
        XCTAssertTrue(element("year.2026-03-01").waitForExistence(timeout: 8))
        snapshot("calendar-year")
        tap("year.2026-03-01")
        XCTAssertTrue(element("month.2026-03-12").waitForExistence(timeout: 8))
        XCTAssertTrue(app.navigationBars["March 2026"].waitForExistence(timeout: 5))
    }

    func testAddingABlockPutsItOnThatDay() {
        openCalendar()
        tap("calendar.add")
        let label = element("editor.label")
        XCTAssertTrue(label.waitForExistence(timeout: 5))
        label.tap()
        label.typeText("dentist")
        snapshot("block-editor")
        tap("editor.save")
        // New blocks start at 9:00 AM, inside "work", which gets trimmed.
        XCTAssertTrue(element("tile.2026-11-05.dentist").waitForExistence(timeout: 8))
    }

    func testSkipOnALaterDayLeavesToday() {
        openCalendar()
        tap("strip.2026-11-06")
        tap("tile.2026-11-06.gym")
        tap("block.skip")
        XCTAssertTrue(element("tile.2026-11-06.gym").waitForExistence(timeout: 5))
        tap("calendar.today")
        XCTAssertTrue(app.navigationBars["Thursday, November 5"].waitForExistence(timeout: 5))
        XCTAssertTrue(element("tile.2026-11-05.gym").waitForExistence(timeout: 5))
    }

    func testDeletingABlockAsksFirst() {
        openCalendar()
        tap("tile.2026-11-05.gym")
        tap("block.delete")
        app.buttons["Delete"].firstMatch.tap()
        let gone = NSPredicate(format: "exists == false")
        wait(for: [expectation(for: gone, evaluatedWith: element("tile.2026-11-05.gym"))], timeout: 8)
    }
}
