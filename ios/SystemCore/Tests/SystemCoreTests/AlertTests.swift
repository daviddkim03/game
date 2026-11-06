import Foundation
import Testing

@testable import SystemCore

private let eastern: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    return calendar
}()

private func at(_ date: CivilDate, _ hour: Int, _ minute: Int = 0) -> Date {
    date.date(minutes: hour * 60 + minute, calendar: eastern)
}

@Suite struct AlertTests {
    // Thursday only: work 8:30-4:30, gym 4:30-5:30, tutoring 6:00-8:00.
    let week = schedule(block(1, 3, 5, 21, "work"), block(2, 3, 21, 23, "gym"), block(3, 3, 24, 28, "tutoring"))
    var quiet: AlertPrefs {
        var prefs = AlertPrefs()
        prefs.timesUp = false
        prefs.morningSummary = false
        return prefs
    }

    private func plan(
        _ schedule: Schedule? = nil,
        days: [String: DayOverride] = [:],
        prefs: AlertPrefs,
        now: Date? = nil,
        limit: Int = AlertPlanner.systemLimit
    ) -> [PlannedAlert] {
        AlertPlanner.plan(
            schedule: schedule ?? week, days: days, prefs: prefs, now: now ?? at(thursday, 7),
            calendar: eastern, limit: limit
        ).filter { $0.kind != .keepAlive }
    }

    private func todays(_ alerts: [PlannedAlert]) -> [PlannedAlert] {
        alerts.filter { $0.date == thursday }
    }

    @Test func firesFiveMinutesBeforeEachNextThingStarts() {
        let alerts = todays(plan(prefs: quiet))
        #expect(alerts.map(\.title) == ["work in 5 min", "gym in 5 min", "tutoring in 5 min"])
        #expect(alerts[0].fireDate == at(thursday, 8, 25))
        #expect(alerts[1].fireDate == at(thursday, 16, 25))
        #expect(alerts[2].fireDate == at(thursday, 17, 55))
    }

    @Test func aGapMeansTheAlertFollowsTheNextStartNotTheLastEnd() {
        // Gym ends at 5:30 and tutoring starts at 6:00: 5:55, not 5:25.
        let alert = todays(plan(prefs: quiet))[2]
        #expect(alert.fireDate == at(thursday, 17, 55))
        #expect(alert.extendBlockId == nil)
        #expect(alert.body == "6:00 PM - 8:00 PM")
    }

    @Test func nothingElseEverDoesAFiveMinutesLeftAlert() {
        let alerts = plan(prefs: AlertPrefs())
        #expect(!alerts.contains { $0.title.contains("left") })
    }

    @Test func wrappingUpNamesWhatIsStillRunningAndCanBeExtended() {
        let alert = todays(plan(prefs: quiet))[1]
        #expect(alert.body == "Wrap up work. 4:30 PM - 5:30 PM")
        #expect(alert.extendBlockId == 1)
        #expect(alert.skipBlockId == 2)
    }

    @Test func timesUpSaysWhatIsNext() {
        var prefs = quiet
        prefs.startingSoon = false
        prefs.timesUp = true
        let alerts = todays(plan(prefs: prefs))
        #expect(alerts.map(\.title) == ["Time's up: work", "Time's up: gym", "Time's up: tutoring"])
        #expect(alerts[0].body == "Next: gym")
        #expect(alerts[1].body == "Next: tutoring at 6:00 PM")
        #expect(alerts[2].body == "Nothing else today")
        #expect(alerts[0].extendBlockId == 1)
    }

    @Test func morningSummaryListsTheDay() {
        var prefs = quiet
        prefs.startingSoon = false
        prefs.morningSummary = true
        prefs.morningMinute = 6 * 60 + 30
        let alert = todays(plan(prefs: prefs, now: at(thursday, 5)))[0]
        #expect(alert.fireDate == at(thursday, 6, 30))
        #expect(alert.body == "work 8:30 AM, gym 4:30 PM, tutoring 6:00 PM")
    }

    @Test func noMorningSummaryOnAnEmptyDay() {
        var prefs = quiet
        prefs.startingSoon = false
        prefs.morningSummary = true
        let alerts = plan(prefs: prefs, now: at(thursday, 5))
        #expect(Set(alerts.map(\.date.mondayIndex)) == [3])
    }

    @Test func alertsInThePastAreDropped() {
        let alerts = todays(plan(prefs: quiet, now: at(thursday, 12)))
        #expect(alerts.map(\.title) == ["gym in 5 min", "tutoring in 5 min"])
    }

    @Test func skippingCancelsThatDatesAlertButNotNextWeeks() {
        let days = [thursday.key: DayOverride(skipped: [2])]
        let alerts = plan(days: days, prefs: quiet)
        #expect(todays(alerts).map(\.title) == ["work in 5 min", "tutoring in 5 min"])
        #expect(alerts.contains { $0.date == thursday.adding(days: 7) && $0.title == "gym in 5 min" })
    }

    @Test func plusFifteenMovesTheNextAlertToo() {
        let days = [thursday.key: DayOverride(extraMinutes: [1: 15])]
        let alert = todays(plan(days: days, prefs: quiet))[1]
        #expect(alert.title == "gym in 5 min")
        #expect(alert.fireDate == at(thursday, 16, 40))
    }

    @Test func mutedLabelsStayQuietButStillShowAsNext() {
        var prefs = AlertPrefs()
        prefs.morningSummary = false
        prefs.muted = ["gym"]
        let alerts = todays(plan(prefs: prefs))
        #expect(!alerts.contains { $0.title.contains("gym") })
        #expect(alerts.first { $0.title == "Time's up: work" }?.body == "Next: gym")
    }

    @Test func aSplitBlockOnlyAlertsOnce() {
        let split = schedule(block(1, 3, 5, 10, "work"), block(2, 3, 10, 21, "work"))
        #expect(todays(plan(split, prefs: quiet)).map(\.title) == ["work in 5 min"])
    }

    @Test func staysWithinTheSystemLimitAndEndsWithAKeepAliveReminder() {
        var blocks: [Block] = []
        for day in 0..<7 {
            for slot in 0..<8 {
                blocks.append(block(day * 100 + slot, day, slot * 3, slot * 3 + 2, "thing \(slot)"))
            }
        }
        let busy = Schedule(blocks: blocks, nextId: 1000, selColor: "#5aab3f", hStart: 6)
        let all = AlertPlanner.plan(
            schedule: busy, days: [:], prefs: AlertPrefs(), now: at(thursday, 7), calendar: eastern)
        #expect(all.count == 64)
        #expect(all.last?.kind == .keepAlive)
        #expect(all.last!.fireDate > all[all.count - 2].fireDate)
        #expect(zip(all, all.dropFirst()).allSatisfy { $0.fireDate <= $1.fireDate })
        #expect(Set(all.map(\.id)).count == 64)
    }

    @Test func anEmptyScheduleSchedulesNothing() {
        #expect(
            AlertPlanner.plan(schedule: .empty, days: [:], prefs: AlertPrefs(), now: at(thursday, 7), calendar: eastern)
                .isEmpty)
    }
}
