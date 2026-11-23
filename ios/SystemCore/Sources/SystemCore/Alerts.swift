import Foundation

/// "gym in 5 min", five minutes before gym starts.
public struct PlannedAlert: Identifiable, Hashable, Sendable {
    public let id: String
    public let date: CivilDate
    public let fireDate: Date
    public let title: String
    public internal(set) var body: String
    /// The thing "Skip today" applies to.
    public let skipBlockId: Int
    /// The running thing "+15 min" lengthens.
    public let extendBlockId: Int?
}

public enum AlertPlanner {
    public static let leadMinutes = 5
    /// iOS keeps only this many pending alerts per app.
    public static let systemLimit = 64
    public static let horizonDays = 14

    /// The alerts to queue, soonest first.
    public static func plan(
        schedule: Schedule,
        phone: PhonePrefs,
        now: Date,
        calendar: Calendar = .current
    ) -> [PlannedAlert] {
        guard phone.areAlertsOn else { return [] }
        let today = CivilDate(now, calendar: calendar)
        let upcoming = (0..<horizonDays).flatMap { offset in
            let date = today.adding(days: offset)
            let plan = dayPlan(for: date, schedule: schedule, override: phone.days[date.key])
            return alerts(for: plan, calendar: calendar)
        }
        .filter { $0.fireDate > now }

        var queue = Array(upcoming.prefix(systemLimit))
        // The last one asks to reopen the app rather than going quiet.
        if let last = queue.indices.last {
            queue[last].body += "\nOpen System to keep notifications on."
        }
        return queue
    }

    private static func alerts(for plan: DayPlan, calendar: Calendar) -> [PlannedAlert] {
        let things = plan.things
        return things.indices.compactMap { index in
            let thing = things[index]
            let leadMinute = thing.start - leadMinutes
            guard leadMinute >= 0 else { return nil }

            let previous = index > 0 ? things[index - 1] : nil
            let running = previous.flatMap { $0.end > leadMinute ? $0 : nil }
            return PlannedAlert(
                id: "soon-\(plan.date.key)-\(thing.id)",
                date: plan.date,
                fireDate: plan.date.date(minutes: leadMinute, calendar: calendar),
                title: "\(thing.label) in \(leadMinutes) min",
                body: running.map { "Wrap up \($0.label). \(thing.timeLabel)" } ?? thing.timeLabel,
                skipBlockId: thing.id,
                extendBlockId: running?.lastBlockId)
        }
    }
}
