import XCTest

final class NowTests: AppTestCase {
    func testShowsWhatIsHappeningNow() {
        launch()
        expect("now.label", "work")
        expect("now.ends", "Ends 4:30 PM")
        XCTAssertTrue(text("now.left").contains("6h 32m"))
        expect("now.next", "Next: gym at 4:30 PM")
        snapshot("now")
    }

    func testPlusFifteenPushesTheEndAndNextStartAndUndoes() {
        launch()
        tap("now.extend")
        expect("now.ends", "Ends 4:45 PM")
        expect("now.next", "Next: gym at 4:45 PM")
        snapshot("now-extended")
        tap("now.extend")
        expect("now.ends", "Ends 5:00 PM")
        tap("now.undoExtend")
        tap("now.undoExtend")
        expect("now.ends", "Ends 4:30 PM")
    }

    func testSkipTodayFreesTheTimeAndCanBeRestored() {
        launch()
        tap("now.skip")
        expect("now.label", "Free")
        snapshot("now-skipped")
        tap("skipped.restore.work")
        expect("now.label", "work")
    }

    func testBetweenThingsShowsFree() {
        launch(at: "2026-11-05T17:45")
        expect("now.label", "Free")
        XCTAssertTrue(text("now.next").contains("tutoring"))
        snapshot("now-free")
    }

    func testAfterTheLastThingOfTheDay() {
        launch(at: "2026-11-05T23:30")
        expect("now.label", "Free")
        XCTAssertTrue(app.staticTexts["Nothing else today"].waitForExistence(timeout: 5))
    }

    func testTodayRowOpensTheBlockWithItsActions() {
        launch()
        tap("today.gym")
        expect("block.title", "gym")
        snapshot("block-sheet")
        tap("block.skip")
        XCTAssertTrue(element("skipped.restore.gym").waitForExistence(timeout: 5))
        expect("now.next", "Next: tutoring at 6:00 PM")
    }

    func testLogsATutoringSessionFromTheCard() {
        launch(at: "2026-11-05T18:30")
        expect("now.label", "tutoring")
        tap("now.log")
        XCTAssertTrue(element("session.save").waitForExistence(timeout: 5))
        snapshot("session-editor")
        tap("session.save")
        openTab("Tutoring")
        // Ana already has 3.5 hours; this adds the block's 2 hours at $40.
        expect("tutoring.total", "Total, $220")
    }
}
