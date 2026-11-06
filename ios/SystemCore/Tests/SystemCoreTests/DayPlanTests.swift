import Foundation
import Testing

@testable import SystemCore

/// Thursday.
let thursday = CivilDate(year: 2026, month: 11, day: 5)

func block(_ id: Int, _ day: Int, _ start: Int, _ end: Int, _ label: String) -> Block {
    Block(id: id, day: day, start: start, end: end, label: label, color: "#5aab3f")
}

func schedule(_ blocks: Block...) -> Schedule {
    Schedule(blocks: blocks, nextId: 100, selColor: "#5aab3f", hStart: 6)
}

@Suite struct CivilDateTests {
    @Test func weekdaysMatchTheScheduleAndJavaScript() {
        #expect(thursday.mondayIndex == 3)
        #expect(thursday.sundayIndex == 4)
        #expect(CivilDate(year: 2026, month: 11, day: 8).mondayIndex == 6)
        #expect(CivilDate(year: 2026, month: 11, day: 9).mondayIndex == 0)
    }

    @Test func arithmeticCrossesMonthsYearsAndDaylightSaving() {
        #expect(CivilDate(year: 2026, month: 12, day: 31).adding(days: 1).key == "2027-01-01")
        // US clocks change on both of these dates.
        #expect(CivilDate(year: 2026, month: 3, day: 8).adding(days: 1).key == "2026-03-09")
        #expect(CivilDate(year: 2026, month: 11, day: 1).adding(days: 1).key == "2026-11-02")
        #expect(CivilDate(year: 2026, month: 1, day: 31).adding(months: 1).key == "2026-02-28")
        #expect(thursday.days(to: thursday.adding(days: 40)) == 40)
        #expect(thursday.startOfWeek.key == "2026-11-02")
    }

    @Test func keysRoundTrip() {
        #expect(CivilDate(key: "2026-11-05") == thursday)
        #expect(CivilDate(key: "nonsense") == nil)
    }

    @Test func momentsUseTheLocalWallClock() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let moment = thursday.date(minutes: 16 * 60 + 30, calendar: calendar)
        #expect(CivilDate.minuteOfDay(moment, calendar: calendar) == 16 * 60 + 30)
        #expect(CivilDate(moment, calendar: calendar) == thursday)
        let midnight = thursday.date(minutes: 24 * 60, calendar: calendar)
        #expect(CivilDate(midnight, calendar: calendar).key == "2026-11-06")
    }
}

@Suite struct DayPlanTests {
    // Thursday: work 8:30-4:30, gym 4:30-5:30, tutoring 6:00-8:00.
    let week = schedule(
        block(1, 3, 5, 21, "work"), block(2, 3, 21, 23, "gym"), block(3, 3, 24, 28, "tutoring"),
        block(4, 2, 0, 2, "other day"))

    @Test func usesOnlyThatWeekdayInTimeOrder() {
        let plan = dayPlan(for: thursday, schedule: week, override: nil)
        #expect(plan.blocks.map(\.label) == ["work", "gym", "tutoring"])
        #expect(plan.blocks[0].start == 8 * 60 + 30)
        #expect(plan.blocks[0].end == 16 * 60 + 30)
    }

    @Test func skippingRemovesABlockForThatDateOnly() {
        let plan = dayPlan(for: thursday, schedule: week, override: DayOverride(skipped: [2]))
        #expect(plan.blocks.map(\.label) == ["work", "tutoring"])
        #expect(plan.skipped.map(\.label) == ["gym"])
        let nextWeek = dayPlan(for: thursday.adding(days: 7), schedule: week, override: nil)
        #expect(nextWeek.blocks.map(\.label) == ["work", "gym", "tutoring"])
    }

    @Test func plusFifteenStartsTheNextThingLateAndKeepsItsEnd() {
        let plan = dayPlan(for: thursday, schedule: week, override: DayOverride(extraMinutes: [1: 15]))
        #expect(plan.blocks[0].end == 16 * 60 + 45)
        #expect(plan.blocks[0].extraMinutes == 15)
        #expect(plan.blocks[1].start == 16 * 60 + 45)
        #expect(plan.blocks[1].end == 17 * 60 + 30)
        #expect(plan.blocks[1].wasPushed)
        #expect(plan.blocks[2].start == 18 * 60)
        #expect(!plan.blocks[2].wasPushed)
    }

    @Test func plusFifteenFillsAGapBeforeTouchingTheNextThing() {
        let plan = dayPlan(for: thursday, schedule: week, override: DayOverride(extraMinutes: [2: 15]))
        #expect(plan.blocks[1].end == 17 * 60 + 45)
        #expect(plan.blocks[2].start == 18 * 60)
    }

    @Test func aBlockFullyCoveredByAnExtensionDropsForTheDay() {
        let plan = dayPlan(for: thursday, schedule: week, override: DayOverride(extraMinutes: [1: 60]))
        #expect(plan.blocks.map(\.label) == ["work", "tutoring"])
        #expect(plan.blocks[0].end == 17 * 60 + 30)
    }

    @Test func extensionsStopAtMidnight() {
        let late = schedule(block(1, 3, 34, 36, "late"))
        let plan = dayPlan(for: thursday, schedule: late, override: DayOverride(extraMinutes: [1: 30]))
        #expect(plan.blocks[0].end == 24 * 60)
    }

    @Test func touchingBlocksWithTheSameLabelReadAsOneThing() {
        let split = schedule(block(1, 3, 0, 4, "work"), block(2, 3, 4, 8, "work"), block(3, 3, 8, 10, "gym"))
        let things = dayPlan(for: thursday, schedule: split, override: nil).things
        #expect(things.map(\.label) == ["work", "gym"])
        #expect(things[0].end == ScheduleGrid.minutes(slot: 8))
        #expect(things[0].lastBlockId == 2)
    }

    @Test func sameLabelWithAGapStaysSeparate() {
        let split = schedule(block(1, 3, 0, 2, "work"), block(2, 3, 4, 8, "work"))
        #expect(dayPlan(for: thursday, schedule: split, override: nil).things.count == 2)
    }

    @Test func nowFindsTheCurrentAndNextThing() {
        let plan = dayPlan(for: thursday, schedule: week, override: nil)
        let morning = plan.now(at: 9 * 60 + 58)
        #expect(morning.current?.label == "work")
        #expect(morning.next?.label == "gym")
        #expect(morning.minutesLeft == 392)
        #expect(abs(morning.progress - 88.0 / 480.0) < 0.0001)

        let gap = plan.now(at: 17 * 60 + 45)
        #expect(gap.current == nil)
        #expect(gap.next?.label == "tutoring")
        #expect(gap.last?.label == "gym")

        let boundary = plan.now(at: 16 * 60 + 30)
        #expect(boundary.current?.label == "gym")

        let night = plan.now(at: 23 * 60)
        #expect(night.current == nil)
        #expect(night.next == nil)
    }

    @Test func durationLabels() {
        #expect(durationLabel(minutes: 392) == "6h 32m")
        #expect(durationLabel(minutes: 120) == "2h")
        #expect(durationLabel(minutes: 31) == "31m")
    }
}

@Suite struct PhonePrefsTests {
    @Test func skipAndRestore() {
        var prefs = PhonePrefs()
        prefs.skip(2, on: thursday)
        #expect(prefs.days[thursday.key]?.skipped == [2])
        prefs.restore(2, on: thursday)
        #expect(prefs.days.isEmpty)
    }

    @Test func extendStacksAndUndoes() {
        var prefs = PhonePrefs()
        prefs.extend(1, on: thursday, by: 15)
        prefs.extend(1, on: thursday, by: 15)
        #expect(prefs.days[thursday.key]?.extraMinutes[1] == 30)
        prefs.extend(1, on: thursday, by: -15)
        prefs.extend(1, on: thursday, by: -15)
        #expect(prefs.days.isEmpty)
    }

    @Test func skippingClearsAnExtension() {
        var prefs = PhonePrefs()
        prefs.extend(1, on: thursday, by: 15)
        prefs.skip(1, on: thursday)
        #expect(prefs.days[thursday.key]?.extraMinutes.isEmpty == true)
    }

    @Test func oldDaysArePruned() {
        var prefs = PhonePrefs()
        prefs.skip(1, on: thursday.adding(days: -31))
        prefs.skip(1, on: thursday.adding(days: -30))
        prefs.skip(1, on: thursday)
        prefs.prune(today: thursday)
        #expect(prefs.days.count == 2)
    }

    @Test func roundTripsThroughJSON() {
        var prefs = PhonePrefs()
        prefs.skip(2, on: thursday)
        prefs.extend(1, on: thursday, by: 15)
        prefs.alerts.timesUp = false
        prefs.alerts.morningMinute = 390
        prefs.alerts.muted = ["sleep"]
        #expect(PhonePrefs(json: prefs.toJSON()) == prefs)
    }
}
