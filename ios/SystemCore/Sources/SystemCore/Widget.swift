import Foundation

/// What the widget needs, left by the app where the widget can read it. The
/// widget works out the time itself, so it stays right without the app running.
public struct WidgetSnapshot: Equatable, Sendable {
    public var schedule: Schedule
    /// Today-only changes, keyed like `PhonePrefs.days`.
    public var days: [String: DayOverride]

    public init(schedule: Schedule, days: [String: DayOverride]) {
        self.schedule = schedule
        self.days = days
    }

    public init?(json: JSONValue) {
        guard let schedule = json["schedule"].flatMap(Schedule.init(json:)),
            let phone = json["phone"].flatMap(PhonePrefs.init(json:))
        else { return nil }
        self.init(schedule: schedule, days: phone.days)
    }

    public func toJSON() -> JSONValue {
        var phone = PhonePrefs()
        phone.days = days
        return ["schedule": schedule.toJSON(), "phone": phone.toJSON()]
    }

    public func moment(at date: Date, calendar: Calendar = .current) -> WidgetMoment {
        let day = CivilDate(date, calendar: calendar)
        let minute = CivilDate.minuteOfDay(date, calendar: calendar)
        let plan = plan(for: day)
        let state = plan.now(at: minute)
        return WidgetMoment(
            date: date,
            state: state,
            upcoming: plan.things.filter { $0.start > minute },
            currentRange: state.current.map {
                day.date(minutes: $0.start, calendar: calendar)...day.date(minutes: $0.end, calendar: calendar)
            })
    }

    /// One moment now, then one each time what's on changes, for this many days.
    public func moments(from start: Date, days count: Int = 2, calendar: Calendar = .current) -> [WidgetMoment] {
        let today = CivilDate(start, calendar: calendar)
        var dates: Set<Date> = [start]
        for offset in 0..<count {
            let day = today.adding(days: offset)
            let things = plan(for: day).things
            for minute in [0] + things.flatMap({ [$0.start, $0.end] }) {
                let date = day.date(minutes: minute, calendar: calendar)
                if date > start { dates.insert(date) }
            }
        }
        return dates.sorted().map { moment(at: $0, calendar: calendar) }
    }

    private func plan(for date: CivilDate) -> DayPlan {
        dayPlan(for: date, schedule: schedule, override: days[date.key])
    }
}

/// What the widget shows from `date` until the next moment.
public struct WidgetMoment: Hashable, Sendable {
    public let date: Date
    public let state: NowState
    /// What's left today, soonest first.
    public let upcoming: [Thing]
    /// When the running thing started and ends.
    public let currentRange: ClosedRange<Date>?

    public var title: String {
        state.current?.label ?? "Free"
    }

    public var subtitle: String {
        if let current = state.current { return "Ends \(clockLabel(current.end))" }
        if let next = state.next { return "Until \(clockLabel(next.start))" }
        return "Nothing else today"
    }

    public var nextLine: String? {
        state.next.map { "Next: \($0.label) at \(clockLabel($0.start))" }
    }

    /// The one-line Lock Screen version.
    public var inlineLine: String {
        if let current = state.current { return "\(current.label) until \(clockLabel(current.end))" }
        if let next = state.next { return "Free until \(clockLabel(next.start))" }
        return "Nothing else today"
    }
}

/// The file the app leaves for the widget.
public struct WidgetStore: Sendable {
    /// Also in both targets' entitlements in project.yml.
    public static let appGroup = "group.com.daviddkim03.system"

    /// The one the app and the widget share. It does nothing in a build
    /// without the app group, such as an unsigned one.
    public static var shared: WidgetStore {
        WidgetStore(directory: FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup))
    }

    private let url: URL?

    public init(directory: URL?) {
        url = directory?.appendingPathComponent("widget.json")
    }

    public func read() -> WidgetSnapshot? {
        guard let url, let data = try? Data(contentsOf: url),
            let json = try? JSONDecoder().decode(JSONValue.self, from: data)
        else { return nil }
        return WidgetSnapshot(json: json)
    }

    /// Says whether anything changed, so the widget only reloads when it must.
    @discardableResult
    public func write(_ snapshot: WidgetSnapshot) -> Bool {
        guard let url, read() != snapshot, let data = try? JSONEncoder().encode(snapshot.toJSON()) else {
            return false
        }
        try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return true
    }

    public func clear() {
        if let url { try? FileManager.default.removeItem(at: url) }
    }
}
