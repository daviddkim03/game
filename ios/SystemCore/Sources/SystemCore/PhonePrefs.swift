import Foundation

/// Everything only the iOS app uses: today-only changes and alert choices. It
/// lives in its own document so the website's saves never touch it.
public struct PhonePrefs: CloudValue {
    public static let pageId = "phone"
    /// Past changes are dropped after this many days.
    public static let keepDays = 30

    /// Today-only changes, keyed by "2026-11-05".
    public var days: [String: DayOverride] = [:]
    public var alerts = AlertPrefs()

    public static let empty = PhonePrefs()
    public static let replacedKeys: Set<String> = ["days", "alerts"]

    public init() {}

    public init?(json: JSONValue) {
        guard case .object = json else { return nil }
        for (key, value) in json["days"]?.objectValue ?? [:] {
            var override = DayOverride()
            override.skipped = Set(value["skipped"]?.intsValue ?? [])
            for (id, minutes) in value["extraMinutes"]?.objectValue ?? [:] {
                if let id = Int(id), let minutes = minutes.intValue {
                    override.extraMinutes[id] = minutes
                }
            }
            if !override.isEmpty { days[key] = override }
        }
        if let saved = json["alerts"] {
            alerts.startingSoon = saved["startingSoon"]?.boolValue ?? true
            alerts.timesUp = saved["timesUp"]?.boolValue ?? true
            alerts.morningSummary = saved["morningSummary"]?.boolValue ?? true
            alerts.morningMinute = saved["morningMinute"]?.intValue ?? 7 * 60
            alerts.muted = Set((saved["muted"]?.arrayValue ?? []).compactMap(\.stringValue))
        }
    }

    public func toJSON() -> JSONValue {
        [
            "days": .object(
                days.mapValues { override in
                    [
                        "skipped": .array(override.skipped.sorted().map { .number(Double($0)) }),
                        "extraMinutes": .object(
                            Dictionary(
                                uniqueKeysWithValues: override.extraMinutes.map {
                                    (String($0.key), JSONValue.number(Double($0.value)))
                                })),
                    ]
                }),
            "alerts": [
                "startingSoon": .bool(alerts.startingSoon),
                "timesUp": .bool(alerts.timesUp),
                "morningSummary": .bool(alerts.morningSummary),
                "morningMinute": .number(Double(alerts.morningMinute)),
                "muted": .array(alerts.muted.sorted().map(JSONValue.string)),
            ],
        ]
    }

    public mutating func skip(_ blockId: Int, on date: CivilDate) {
        days[date.key, default: DayOverride()].skipped.insert(blockId)
        days[date.key]?.extraMinutes[blockId] = nil
    }

    public mutating func restore(_ blockId: Int, on date: CivilDate) {
        days[date.key]?.skipped.remove(blockId)
        clean(date)
    }

    public mutating func extend(_ blockId: Int, on date: CivilDate, by minutes: Int) {
        let total = (days[date.key]?.extraMinutes[blockId] ?? 0) + minutes
        days[date.key, default: DayOverride()].extraMinutes[blockId] = total > 0 ? total : nil
        clean(date)
    }

    public mutating func prune(today: CivilDate) {
        let cutoff = today.adding(days: -Self.keepDays)
        days = days.filter { key, _ in
            CivilDate(key: key).map { $0 >= cutoff } ?? false
        }
    }

    private mutating func clean(_ date: CivilDate) {
        if days[date.key]?.isEmpty == true { days[date.key] = nil }
    }
}
