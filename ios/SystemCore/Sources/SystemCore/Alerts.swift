import Foundation

public struct AlertPrefs: Hashable, Sendable {
    /// "gym in 5 min", five minutes before the next thing starts.
    public var startingSoon = true
    /// "Time's up: work", when a thing ends.
    public var timesUp = true
    public var morningSummary = true
    /// Minutes past midnight.
    public var morningMinute = 7 * 60
    /// Labels that never alert.
    public var muted: Set<String> = []

    public init() {}
}

public struct PlannedAlert: Identifiable, Hashable, Sendable {
    public enum Kind: String, Sendable {
        case startingSoon, timesUp, morningSummary, keepAlive
    }

    public let id: String
    public let kind: Kind
    public let date: CivilDate
    public let fireDate: Date
    public let title: String
    public let body: String
    /// The thing "Skip" applies to.
    public let skipBlockId: Int?
    /// The running thing "+15 min" lengthens.
    public let extendBlockId: Int?

    public init(
        id: String, kind: Kind, date: CivilDate, fireDate: Date, title: String, body: String,
        skipBlockId: Int?, extendBlockId: Int?
    ) {
        self.id = id
        self.kind = kind
        self.date = date
        self.fireDate = fireDate
        self.title = title
        self.body = body
        self.skipBlockId = skipBlockId
        self.extendBlockId = extendBlockId
    }
}

public enum AlertPlanner {
    public static let leadMinutes = 5
    /// iOS keeps only this many pending alerts per app.
    public static let systemLimit = 64
    public static let horizonDays = 14

    public static func plan(
        schedule: Schedule,
        days: [String: DayOverride],
        prefs: AlertPrefs,
        now: Date,
        calendar: Calendar = .current,
        limit: Int = systemLimit
    ) -> [PlannedAlert] {
        let today = CivilDate(now, calendar: calendar)
        var alerts: [PlannedAlert] = []
        for offset in 0..<horizonDays {
            let date = today.adding(days: offset)
            let plan = dayPlan(for: date, schedule: schedule, override: days[date.key])
            alerts += self.alerts(for: plan, prefs: prefs, calendar: calendar)
        }
        let upcoming =
            alerts
            .filter { $0.fireDate > now }
            .sorted { ($0.fireDate, $0.id) < ($1.fireDate, $1.id) }
        guard limit > 1, let cutoff = upcoming.prefix(limit - 1).last else { return [] }

        // The final slot asks to reopen the app rather than going quiet.
        let reminder = PlannedAlert(
            id: "keep-alive",
            kind: .keepAlive,
            date: CivilDate(cutoff.fireDate, calendar: calendar),
            fireDate: cutoff.fireDate.addingTimeInterval(60),
            title: "Open System to keep your alerts on",
            body: "Alerts for your schedule run out soon.",
            skipBlockId: nil,
            extendBlockId: nil)
        return Array(upcoming.prefix(limit - 1)) + [reminder]
    }

    private static func alerts(
        for plan: DayPlan,
        prefs: AlertPrefs,
        calendar: Calendar
    ) -> [PlannedAlert] {
        let date = plan.date
        let things = plan.things
        var alerts: [PlannedAlert] = []

        func moment(_ minute: Int) -> Date {
            date.date(minutes: minute, calendar: calendar)
        }

        if prefs.morningSummary, !things.isEmpty {
            let list = things.map { "\($0.label) \(clockLabel($0.start))" }.joined(separator: ", ")
            alerts.append(
                PlannedAlert(
                    id: "morning-\(date.key)",
                    kind: .morningSummary,
                    date: date,
                    fireDate: moment(prefs.morningMinute),
                    title: "Today",
                    body: list,
                    skipBlockId: nil,
                    extendBlockId: nil))
        }

        for (index, thing) in things.enumerated() {
            let isMuted = prefs.muted.contains(thing.label)
            let previous = index > 0 ? things[index - 1] : nil
            let next = index + 1 < things.count ? things[index + 1] : nil
            let leadMinute = thing.start - leadMinutes

            if prefs.startingSoon, !isMuted, leadMinute >= 0 {
                let running = previous.flatMap { $0.end > leadMinute ? $0 : nil }
                alerts.append(
                    PlannedAlert(
                        id: "soon-\(date.key)-\(thing.id)",
                        kind: .startingSoon,
                        date: date,
                        fireDate: moment(leadMinute),
                        title: "\(thing.label) in \(leadMinutes) min",
                        body: running.map { "Wrap up \($0.label). \(thing.timeLabel)" } ?? thing.timeLabel,
                        skipBlockId: thing.id,
                        extendBlockId: running?.lastBlockId))
            }

            if prefs.timesUp, !isMuted {
                let body: String
                if let next {
                    body =
                        next.start == thing.end
                        ? "Next: \(next.label)"
                        : "Next: \(next.label) at \(clockLabel(next.start))"
                } else {
                    body = "Nothing else today"
                }
                alerts.append(
                    PlannedAlert(
                        id: "up-\(date.key)-\(thing.id)",
                        kind: .timesUp,
                        date: date,
                        fireDate: moment(thing.end),
                        title: "Time's up: \(thing.label)",
                        body: body,
                        skipBlockId: nil,
                        extendBlockId: thing.lastBlockId))
            }
        }
        return alerts
    }
}
