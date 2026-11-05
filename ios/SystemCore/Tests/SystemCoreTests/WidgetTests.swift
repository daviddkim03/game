import Foundation
import Testing

@testable import SystemCore

@Suite struct WidgetMomentTests {
    /// Thursday: work 9:00 to noon, gym 1:00 to 2:00 PM.
    let week = schedule(block(1, 3, 6, 12, "work"), block(2, 3, 14, 16, "gym"))

    func time(_ hour: Int, _ minute: Int = 0, on day: CivilDate = thursday) -> Date {
        day.date(minutes: hour * 60 + minute)
    }

    func clock(_ date: Date) -> String {
        clockLabel(CivilDate.minuteOfDay(date))
    }

    @Test func aMomentStartsEveryTimeWhatsOnChanges() {
        let moments = WidgetSnapshot(schedule: week, days: [:]).moments(from: time(8, 30))
        #expect(moments.map(\.title) == ["Free", "work", "Free", "gym", "Free", "Free"])
        #expect(moments.map { clock($0.date) } == ["8:30 AM", "9:00 AM", "12:00 PM", "1:00 PM", "2:00 PM", "12:00 AM"])
    }

    @Test func eachMomentSaysWhenItEndsAndWhatsNext() {
        let snapshot = WidgetSnapshot(schedule: week, days: [:])

        let working = snapshot.moment(at: time(10))
        #expect(working.title == "work")
        #expect(working.subtitle == "Ends 12:00 PM")
        #expect(working.nextLine == "Next: gym at 1:00 PM")
        #expect(working.inlineLine == "work until 12:00 PM")
        #expect(working.currentRange == time(9)...time(12))

        let lunch = snapshot.moment(at: time(12, 30))
        #expect(lunch.title == "Free")
        #expect(lunch.subtitle == "Until 1:00 PM")
        #expect(lunch.inlineLine == "Free until 1:00 PM")
        #expect(lunch.currentRange == nil)

        let evening = snapshot.moment(at: time(20))
        #expect(evening.subtitle == "Nothing else today")
        #expect(evening.nextLine == nil)
        #expect(evening.inlineLine == "Nothing else today")
    }

    @Test func upcomingListsWhatsLeftToday() {
        let week = schedule(
            block(1, 3, 6, 8, "work"), block(2, 3, 8, 10, "gym"), block(3, 3, 12, 14, "study"))
        let moment = WidgetSnapshot(schedule: week, days: [:]).moment(at: time(9, 30))
        #expect(moment.upcoming.map(\.label) == ["gym", "study"])
    }

    @Test func aSkippedBlockIsGone() {
        let days = [thursday.key: DayOverride(skipped: [2])]
        let moments = WidgetSnapshot(schedule: week, days: days).moments(from: time(8, 30))
        #expect(!moments.map(\.title).contains("gym"))
        #expect(moments[1].nextLine == nil)
    }

    @Test func plusFifteenMovesTheEnd() {
        let days = [thursday.key: DayOverride(extraMinutes: [1: 15])]
        let moment = WidgetSnapshot(schedule: week, days: days).moment(at: time(11, 55))
        #expect(moment.subtitle == "Ends 12:15 PM")
        #expect(moment.currentRange?.upperBound == time(12, 15))
    }

    @Test func touchingBlocksWithTheSameLabelReadAsOne() {
        let week = schedule(block(1, 3, 6, 8, "work"), block(2, 3, 8, 10, "work"))
        let moments = WidgetSnapshot(schedule: week, days: [:]).moments(from: time(9), days: 1)
        #expect(moments.count == 2)
        #expect(moments[0].subtitle == "Ends 11:00 AM")
    }

    @Test func itKeepsGoingPastMidnight() {
        let week = schedule(block(1, 3, 30, 36, "late"), block(2, 4, 6, 8, "friday"))
        let moments = WidgetSnapshot(schedule: week, days: [:]).moments(from: time(22))
        #expect(moments.map(\.title) == ["late", "Free", "friday", "Free"])
        let friday = thursday.adding(days: 1)
        #expect(moments[1].date == friday.date(minutes: 0))
        #expect(moments[1].nextLine == "Next: friday at 9:00 AM")
    }

    @Test func anEmptyWeekIsStillAValidTimeline() {
        let moments = WidgetSnapshot(schedule: .empty, days: [:]).moments(from: time(10))
        #expect(moments.map(\.title) == ["Free", "Free"])
        #expect(moments[0].subtitle == "Nothing else today")
    }

    @Test func momentsAreAlwaysInOrderWithNoRepeats() {
        let moments = WidgetSnapshot(schedule: week, days: [:]).moments(from: time(9))
        let dates = moments.map(\.date)
        #expect(dates == dates.sorted())
        #expect(Set(dates).count == dates.count)
    }
}

@Suite struct WidgetStoreTests {
    func store() throws -> (WidgetStore, URL) {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return (WidgetStore(directory: folder), folder)
    }

    let snapshot = WidgetSnapshot(
        schedule: schedule(block(1, 3, 6, 12, "work")),
        days: [thursday.key: DayOverride(skipped: [1], extraMinutes: [2: 15])])

    @Test func theWidgetReadsWhatTheAppWrote() throws {
        let (store, folder) = try store()
        defer { try? FileManager.default.removeItem(at: folder) }
        #expect(store.read() == nil)
        store.write(snapshot)
        #expect(store.read() == snapshot)
    }

    /// The app polls every 30 seconds, so an unchanged snapshot has to stay quiet.
    @Test func writingTheSameThingAgainChangesNothing() throws {
        let (store, folder) = try store()
        defer { try? FileManager.default.removeItem(at: folder) }
        #expect(store.write(snapshot))
        #expect(!store.write(snapshot))
        var skipped = snapshot
        skipped.days = [:]
        #expect(store.write(skipped))
    }

    @Test func clearingLeavesNothing() throws {
        let (store, folder) = try store()
        defer { try? FileManager.default.removeItem(at: folder) }
        store.write(snapshot)
        store.clear()
        #expect(store.read() == nil)
    }

    @Test func aBuildWithoutTheAppGroupDoesNothing() {
        let store = WidgetStore(directory: nil)
        #expect(!store.write(snapshot))
        #expect(store.read() == nil)
        store.clear()
    }
}
