import Foundation

public struct SpendEntry: Identifiable, Hashable, Sendable {
    public enum Source: String, Sendable {
        case manual
        case applePay = "apple_pay"
    }

    public var id: String
    public var date: Date
    public var amount: Double
    public var merchant: String
    /// A tracker category, or nil until one is picked.
    public var category: String?
    public var source: Source

    public init(
        id: String = UUID().uuidString, date: Date, amount: Double, merchant: String,
        category: String? = nil, source: Source = .manual
    ) {
        self.id = id
        self.date = date
        self.amount = amount
        self.merchant = merchant
        self.category = category
        self.source = source
    }
}

/// One month of purchases. Each month is its own document so none of them can
/// outgrow Firestore's size limit.
public struct SpendingMonth: CloudValue {
    public var entries: [SpendEntry]

    public static let empty = SpendingMonth(entries: [])
    public static let replacedKeys: Set<String> = ["entries"]

    public static func pageId(_ date: CivilDate) -> String {
        String(format: "spending_%04d_%02d", date.year, date.month)
    }

    public init(entries: [SpendEntry]) {
        self.entries = entries
    }

    public init?(json: JSONValue) {
        guard case .object = json else { return nil }
        let formatter = ISO8601DateFormatter()
        entries = (json["entries"]?.arrayValue ?? []).compactMap { item in
            guard let id = item["id"]?.stringValue,
                let at = item["at"]?.stringValue,
                let date = formatter.date(from: at),
                let amount = item["amount"]?.doubleValue
            else { return nil }
            return SpendEntry(
                id: id,
                date: date,
                amount: amount,
                merchant: item["merchant"]?.stringValue ?? "",
                category: item["category"]?.stringValue,
                source: item["source"]?.stringValue.flatMap(SpendEntry.Source.init) ?? .manual)
        }
    }

    public func toJSON() -> JSONValue {
        let formatter = ISO8601DateFormatter()
        return [
            "entries": .array(
                entries.map { entry in
                    var json: [String: JSONValue] = [
                        "id": .string(entry.id),
                        "at": .string(formatter.string(from: entry.date)),
                        "amount": .number(entry.amount),
                        "merchant": .string(entry.merchant),
                        "source": .string(entry.source.rawValue),
                    ]
                    if let category = entry.category { json["category"] = .string(category) }
                    return .object(json)
                })
        ]
    }

    public var total: Double {
        entries.reduce(0) { $0 + $1.amount }
    }

    /// Newest first.
    public var sorted: [SpendEntry] {
        entries.sorted { $0.date > $1.date }
    }

    public func total(forCategory category: String?) -> Double {
        entries.filter { $0.category == category }.reduce(0) { $0 + $1.amount }
    }

    public mutating func add(_ entry: SpendEntry) {
        entries.append(entry)
    }

    public mutating func save(_ entry: SpendEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }
    }

    public mutating func delete(_ id: String) {
        entries.removeAll { $0.id == id }
    }

    /// True when the same purchase was logged within the last minute, which
    /// happens when an automation fires twice for one tap.
    public func hasDuplicate(amount: Double, merchant: String, near date: Date) -> Bool {
        entries.contains {
            $0.source == .applePay && $0.amount == amount
                && $0.merchant.caseInsensitiveCompare(merchant) == .orderedSame
                && abs($0.date.timeIntervalSince(date)) < 60
        }
    }
}

/// What a category can still spend: its expenses with no due date. Dated bills
/// are autopay, so they never show up as purchases to log against the plan.
public struct FlexiblePlan: Hashable, Sendable {
    public let byCategory: [String: Double]

    public init(_ data: TrackerData) {
        var totals: [String: Double] = [:]
        for expense in data.expenses
        where expense.cat != TrackerConstants.uncategorized && !expense.hasDueDate {
            totals[expense.cat, default: 0] += expense.monthlyCost
        }
        byCategory = totals
    }

    public var total: Double {
        byCategory.values.reduce(0, +)
    }
}

/// Reads "$12.34", "12.34 USD", "1,234.50", or "12,34".
public func parseAmount(_ text: String) -> Double? {
    let kept = text.filter { $0.isNumber || $0 == "." || $0 == "," }
    guard !kept.isEmpty else { return nil }
    var normalized = kept
    if let dot = kept.lastIndex(of: "."), let comma = kept.lastIndex(of: ",") {
        let decimal: Character = dot > comma ? "." : ","
        let grouping: Character = dot > comma ? "," : "."
        normalized = kept.filter { $0 != grouping }
        if decimal == "," { normalized = normalized.replacingOccurrences(of: ",", with: ".") }
    } else if let comma = kept.lastIndex(of: ",") {
        let digitsAfter = kept.distance(from: comma, to: kept.endIndex) - 1
        normalized =
            digitsAfter == 2
            ? kept.replacingOccurrences(of: ",", with: ".")
            : kept.replacingOccurrences(of: ",", with: "")
    }
    guard let value = Double(normalized), value > 0, value.isFinite else { return nil }
    return (value * 100).rounded() / 100
}
