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

    private func plan(
        _ schedule: Schedule? = nil,
        days: [String: DayOverride] = [:],
        prefs: AlertPrefs = AlertPrefs(),
        now: Date? = nil
    ) -> [PlannedAlert] {
        AlertPlanner.plan(
            schedule: schedule ?? week, days: days, prefs: prefs, now: now ?? at(thursday, 7), calendar: eastern)
    }

    private func todays(_ alerts: [PlannedAlert]) -> [PlannedAlert] {
        alerts.filter { $0.date == thursday }
    }

    @Test func firesFiveMinutesBeforeEachNextThingStarts() {
        let alerts = todays(plan())
        #expect(alerts.map(\.title) == ["work in 5 min", "gym in 5 min", "tutoring in 5 min"])
        #expect(alerts[0].fireDate == at(thursday, 8, 25))
        #expect(alerts[1].fireDate == at(thursday, 16, 25))
        #expect(alerts[2].fireDate == at(thursday, 17, 55))
    }

    @Test func aGapMeansTheAlertFollowsTheNextStartNotTheLastEnd() {
        // Gym ends at 5:30 and tutoring starts at 6:00: 5:55, not 5:25.
        let alert = todays(plan())[2]
        #expect(alert.fireDate == at(thursday, 17, 55))
        #expect(alert.extendBlockId == nil)
        #expect(alert.body == "6:00 PM - 8:00 PM")
    }

    @Test func nothingElseAlerts() {
        // Two Thursdays of three things each, and not one more.
        let alerts = plan(now: at(thursday, 0))
        #expect(alerts.count == 6)
        #expect(alerts.allSatisfy { $0.title.hasSuffix(" in 5 min") })
    }

    @Test func turnedOffNothingAlerts() {
        var prefs = AlertPrefs()
        prefs.startingSoon = false
        #expect(plan(prefs: prefs).isEmpty)
    }

    @Test func wrappingUpNamesWhatIsStillRunningAndCanBeExtended() {
        let alert = todays(plan())[1]
        #expect(alert.body == "Wrap up work. 4:30 PM - 5:30 PM")
        #expect(alert.extendBlockId == 1)
        #expect(alert.skipBlockId == 2)
    }

    @Test func alertsInThePastAreDropped() {
        let alerts = todays(plan(now: at(thursday, 12)))
        #expect(alerts.map(\.title) == ["gym in 5 min", "tutoring in 5 min"])
    }

    @Test func skippingCancelsThatDatesAlertButNotNextWeeks() {
        let days = [thursday.key: DayOverride(skipped: [2])]
        let alerts = plan(days: days)
        #expect(todays(alerts).map(\.title) == ["work in 5 min", "tutoring in 5 min"])
        #expect(alerts.contains { $0.date == thursday.adding(days: 7) && $0.title == "gym in 5 min" })
    }

    @Test func plusFifteenMovesTheNextAlertToo() {
        let days = [thursday.key: DayOverride(extraMinutes: [1: 15])]
        let alert = todays(plan(days: days))[1]
        #expect(alert.title == "gym in 5 min")
        #expect(alert.fireDate == at(thursday, 16, 40))
    }

    @Test func mutedLabelsStayQuietButCanStillNeedWrappingUp() {
        var prefs = AlertPrefs()
        prefs.muted = ["work"]
        let alerts = todays(plan(prefs: prefs))
        #expect(alerts.map(\.title) == ["gym in 5 min", "tutoring in 5 min"])
        #expect(alerts[0].body == "Wrap up work. 4:30 PM - 5:30 PM")
    }

    @Test func aSplitBlockOnlyAlertsOnce() {
        let split = schedule(block(1, 3, 5, 10, "work"), block(2, 3, 10, 21, "work"))
        #expect(todays(plan(split)).map(\.title) == ["work in 5 min"])
    }

    @Test func staysWithinTheSystemLimit() {
        var blocks: [Block] = []
        for day in 0..<7 {
            for slot in 0..<8 {
                blocks.append(block(day * 100 + slot, day, slot * 3, slot * 3 + 2, "thing \(slot)"))
            }
        }
        let busy = Schedule(blocks: blocks, nextId: 1000, selColor: "#5aab3f", hStart: 6)
        let alerts = plan(busy)
        #expect(alerts.count == 64)
        #expect(zip(alerts, alerts.dropFirst()).allSatisfy { $0.fireDate < $1.fireDate })
        #expect(Set(alerts.map(\.id)).count == 64)
    }

    @Test func onlyTheLastAlertAsksToReopenTheApp() {
        let alerts = plan()
        #expect(alerts.last?.title == "tutoring in 5 min")
        #expect(alerts.last?.body == "6:00 PM - 8:00 PM\nOpen System to keep notifications on.")
        #expect(!alerts.dropLast().contains { $0.body.contains("Open System") })
    }

    @Test func anEmptyScheduleSchedulesNothing() {
        #expect(plan(.empty).isEmpty)
    }
}
