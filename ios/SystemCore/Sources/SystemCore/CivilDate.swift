import Foundation

/// A calendar day with no time or time zone, which is what the schedule's
/// repeating week and today-only changes are written against.
public struct CivilDate: Hashable, Comparable, Identifiable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    /// Day arithmetic runs in UTC so daylight saving can never skip a date.
    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// The day `date` falls on in `calendar`'s time zone.
    public init(_ date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    /// Reads "2026-11-05".
    public init?(key: String) {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }

    public var id: String { key }

    /// "2026-11-05".
    public var key: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public static func < (lhs: CivilDate, rhs: CivilDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    private var utcDate: Date {
        Self.utc.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    /// The moment `minutes` past midnight on this day, in `calendar`'s zone.
    public func date(minutes: Int = 0, calendar: Calendar = .current) -> Date {
        let base = calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
        guard minutes > 0 else { return base }
        if minutes >= 24 * 60 {
            return adding(days: minutes / (24 * 60)).date(minutes: minutes % (24 * 60), calendar: calendar)
        }
        let parts = DateComponents(
            year: year, month: month, day: day, hour: minutes / 60, minute: minutes % 60)
        return calendar.date(from: parts) ?? base
    }

    public func adding(days: Int) -> CivilDate {
        let moved = Self.utc.date(byAdding: .day, value: days, to: utcDate) ?? utcDate
        return CivilDate(moved, calendar: Self.utc)
    }

    /// The same day in another month, or that month's last day if it is shorter.
    public func adding(months: Int) -> CivilDate {
        let first = CivilDate(year: year, month: month, day: 1)
        let moved = Self.utc.date(byAdding: .month, value: months, to: first.utcDate) ?? first.utcDate
        let target = CivilDate(moved, calendar: Self.utc)
        return CivilDate(year: target.year, month: target.month, day: min(day, target.daysInMonth))
    }

    /// 0 = Monday ... 6 = Sunday, matching the schedule's `day`.
    public var mondayIndex: Int {
        (sundayIndex + 6) % 7
    }

    /// 0 = Sunday ... 6 = Saturday, matching JavaScript's `getDay()`.
    public var sundayIndex: Int {
        Self.utc.component(.weekday, from: utcDate) - 1
    }

    public var daysInMonth: Int {
        Self.utc.range(of: .day, in: .month, for: utcDate)?.count ?? 30
    }

    public var firstOfMonth: CivilDate {
        CivilDate(year: year, month: month, day: 1)
    }

    /// The Monday of this day's week.
    public var startOfWeek: CivilDate {
        adding(days: -mondayIndex)
    }

    /// Whole days from this day to `other`.
    public func days(to other: CivilDate) -> Int {
        Int(((other.utcDate.timeIntervalSince(utcDate)) / 86_400).rounded())
    }

    /// Minutes past midnight for `date`.
    public static func minuteOfDay(_ date: Date, calendar: Calendar = .current) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}
