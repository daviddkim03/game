import Foundation

public enum TrackerConstants {
    public static let uncategorized = "Uncategorized"
    public static let shortDays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    public static let incomeColors = [
        "#639922", "#378ADD", "#7F77DD", "#D85A30", "#1abc9c", "#e67e22", "#e91e8c",
    ]
    public static let colorPool = [
        "#E24B4A", "#ea9f27", "#1abc9c", "#e91e8c", "#00bcd4", "#8bc34a", "#ff5722",
    ]
    public static let neutralColor = "#888780"
    public static let paydayColor = "#639922"
    public static let weeksPerMonth = 52.0 / 12.0
}

public struct IncomeSource: Identifiable, Hashable, Sendable {
    public var id: Int
    public var name: String
    public var incomeType: String
    public var isTaxed: Bool
    public var isHourly: Bool
    /// Monthly salary (salary only).
    public var monthly: Double?
    /// Hourly rate, or the annual bonus for a salaried source.
    public var rate: Double?
    public var hrsPerWeek: Double?
    public var paydayIsWeekdays: Bool
    /// Days of the month (1-31).
    public var paydayDates: [Int]
    /// 0 = Sunday.
    public var paydayWeekdays: [Int]
    public var showOnCal: Bool

    public init(
        id: Int, name: String, incomeType: String, isTaxed: Bool = true, isHourly: Bool = false,
        monthly: Double? = 0, rate: Double? = nil, hrsPerWeek: Double? = nil,
        paydayIsWeekdays: Bool = false, paydayDates: [Int] = [], paydayWeekdays: [Int] = [],
        showOnCal: Bool = true
    ) {
        self.id = id
        self.name = name
        self.incomeType = incomeType
        self.isTaxed = isTaxed
        self.isHourly = isHourly
        self.monthly = monthly
        self.rate = rate
        self.hrsPerWeek = hrsPerWeek
        self.paydayIsWeekdays = paydayIsWeekdays
        self.paydayDates = paydayDates
        self.paydayWeekdays = paydayWeekdays
        self.showOnCal = showOnCal
    }

    init?(json: JSONValue) {
        guard let id = json["id"]?.intValue else { return nil }
        let rate = json["rate"]?.doubleValue
        let monthly = json["monthly"]?.doubleValue
        let payType = json["payType"]?.stringValue
        var dates = json["paydayDates"]?.intsValue ?? []
        if json["paydayType"]?.stringValue == nil, let legacy = json["payday"]?.stringValue {
            // Older saves wrote paydays as text, like "1st & 15th".
            dates = legacy.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        }
        self.init(
            id: id,
            name: json["name"]?.stringValue ?? "",
            incomeType: json["incomeType"]?.stringValue.flatMap { $0.isEmpty ? nil : $0 } ?? "Other",
            isTaxed: json["type"]?.stringValue != "Untaxed",
            isHourly: payType.map { $0 == "Hourly" } ?? ((rate ?? 0) != 0 && (monthly ?? 0) == 0),
            monthly: monthly,
            rate: rate,
            hrsPerWeek: json["hrsPerWeek"]?.doubleValue.flatMap { $0 == 0 ? nil : $0 },
            paydayIsWeekdays: json["paydayType"]?.stringValue == "weekdays",
            paydayDates: dates,
            paydayWeekdays: json["paydayWeekdays"]?.intsValue ?? [],
            showOnCal: json["showOnCal"]?.boolValue ?? true)
    }

    func toJSON() -> JSONValue {
        [
            "id": .number(Double(id)),
            "name": .string(name),
            "incomeType": .string(incomeType),
            "type": .string(isTaxed ? "Taxed" : "Untaxed"),
            "payType": .string(isHourly ? "Hourly" : "Salary"),
            "monthly": monthly.map(JSONValue.number) ?? .null,
            "rate": rate.map(JSONValue.number) ?? .null,
            "hrsPerWeek": hrsPerWeek.map(JSONValue.number) ?? .null,
            "paydayType": .string(paydayIsWeekdays ? "weekdays" : "dates"),
            "paydayDates": .array(paydayDates.map { .number(Double($0)) }),
            "paydayWeekdays": .array(paydayWeekdays.map { .number(Double($0)) }),
            "showOnCal": .bool(showOnCal),
        ]
    }

    /// Gross monthly pay. Hourly pay counts four weeks a month.
    public var monthlyGross: Double {
        isHourly ? (rate ?? 0) * (hrsPerWeek ?? 0) * 4 : monthly ?? 0
    }

    public func monthlyNet(taxRate: Double) -> Double {
        isTaxed ? monthlyGross * (1 - taxRate) : monthlyGross
    }

    public var paydayLabel: String {
        paydayIsWeekdays
            ? weekdaysLabel(paydayWeekdays) : datesLabel(paydayDates)
    }
}

public struct Expense: Identifiable, Hashable, Sendable {
    public var id: Int
    public var name: String
    public var cat: String
    /// Monthly cost, or the cost per occurrence for weekday bills.
    public var cost: Double
    public var dueIsWeekdays: Bool
    public var due: Int?
    public var dueWeekdays: [Int]
    public var showOnCal: Bool
    public var paymentLink: String?

    public init(
        id: Int, name: String, cat: String, cost: Double, dueIsWeekdays: Bool = false,
        due: Int? = nil, dueWeekdays: [Int] = [], showOnCal: Bool = true, paymentLink: String? = nil
    ) {
        self.id = id
        self.name = name
        self.cat = cat
        self.cost = cost
        self.dueIsWeekdays = dueIsWeekdays
        self.due = due
        self.dueWeekdays = dueWeekdays
        self.showOnCal = showOnCal
        self.paymentLink = paymentLink
    }

    init?(json: JSONValue) {
        guard let id = json["id"]?.intValue else { return nil }
        self.init(
            id: id,
            name: json["name"]?.stringValue ?? "",
            cat: json["cat"]?.stringValue ?? TrackerConstants.uncategorized,
            cost: json["cost"]?.doubleValue ?? 0,
            dueIsWeekdays: json["dueType"]?.stringValue == "weekdays",
            due: json["due"]?.intValue,
            dueWeekdays: json["dueWeekdays"]?.intsValue ?? [],
            showOnCal: json["showOnCal"]?.boolValue ?? true,
            paymentLink: json["paymentLink"]?.stringValue)
    }

    func toJSON() -> JSONValue {
        var json: [String: JSONValue] = [
            "id": .number(Double(id)),
            "name": .string(name),
            "cat": .string(cat),
            "cost": .number(cost),
            "dueType": .string(dueIsWeekdays ? "weekdays" : "dates"),
            "due": due.map { .number(Double($0)) } ?? .null,
            "dueWeekdays": .array(dueWeekdays.map { .number(Double($0)) }),
            "showOnCal": .bool(showOnCal),
        ]
        if let paymentLink { json["paymentLink"] = .string(paymentLink) }
        return .object(json)
    }

    public var monthlyCost: Double {
        dueIsWeekdays
            ? cost * Double(dueWeekdays.count) * TrackerConstants.weeksPerMonth : cost
    }

    public var hasDueDate: Bool {
        dueIsWeekdays ? !dueWeekdays.isEmpty : due != nil
    }

    public var dueLabel: String {
        if dueIsWeekdays { return weekdaysLabel(dueWeekdays) }
        return due.map { "\($0)\(ordinalSuffix($0))" } ?? "-"
    }

    /// Earlier due days first, undated items last.
    public var dueSortKey: Int {
        dueIsWeekdays ? (dueWeekdays.first ?? 99) + 1 : due ?? 99
    }
}

public struct TrackerData: CloudValue {
    public var taxRate: Double
    public var income: [IncomeSource]
    public var incomeTypes: [String]
    public var categories: [String]
    public var catColors: [String: String]
    public var expenses: [Expense]
    public var nextId: Int

    public static let empty = TrackerData(
        taxRate: 0.25, income: [], incomeTypes: ["Other"], categories: [], catColors: [:],
        expenses: [], nextId: 1)
    /// Deleted categories have to disappear from the color map too.
    public static let replacedKeys: Set<String> = ["catColors"]

    public init(
        taxRate: Double, income: [IncomeSource], incomeTypes: [String], categories: [String],
        catColors: [String: String], expenses: [Expense], nextId: Int
    ) {
        self.taxRate = taxRate
        self.income = income
        self.incomeTypes = incomeTypes
        self.categories = categories
        self.catColors = catColors
        self.expenses = expenses
        self.nextId = nextId
    }

    /// Upgrades data saved by any earlier version of the website.
    public init?(json: JSONValue) {
        guard case .object = json else { return nil }
        let income = (json["income"]?.arrayValue ?? []).compactMap(IncomeSource.init(json:))
        var incomeTypes = (json["incomeTypes"]?.arrayValue ?? []).compactMap(\.stringValue)
        for source in income where !incomeTypes.contains(source.incomeType) {
            incomeTypes.append(source.incomeType)
        }
        if incomeTypes.isEmpty { incomeTypes = ["Other"] }
        self.init(
            taxRate: json["taxRate"]?.doubleValue ?? 0.25,
            income: income,
            incomeTypes: incomeTypes,
            categories: (json["categories"]?.arrayValue ?? []).compactMap(\.stringValue),
            catColors: (json["catColors"]?.objectValue ?? [:]).compactMapValues(\.stringValue),
            expenses: (json["expenses"]?.arrayValue ?? []).compactMap(Expense.init(json:)),
            nextId: json["nextId"]?.intValue ?? 1)
    }

    public func toJSON() -> JSONValue {
        [
            "taxRate": .number(taxRate),
            "income": .array(income.map { $0.toJSON() }),
            "incomeTypes": .array(incomeTypes.map(JSONValue.string)),
            "categories": .array(categories.map(JSONValue.string)),
            "catColors": .object(catColors.mapValues(JSONValue.string)),
            "expenses": .array(expenses.map { $0.toJSON() }),
            "nextId": .number(Double(nextId)),
        ]
    }

    public func color(forCategory category: String) -> String {
        catColors[category] ?? TrackerConstants.neutralColor
    }

    public func incomeColor(_ index: Int) -> String {
        TrackerConstants.incomeColors[index % TrackerConstants.incomeColors.count]
    }

    // MARK: Edits

    public mutating func save(_ source: IncomeSource) {
        if let index = income.firstIndex(where: { $0.id == source.id }) {
            income[index] = source
        } else {
            var added = source
            added.id = nextId
            nextId += 1
            income.append(added)
        }
        if !incomeTypes.contains(source.incomeType) { incomeTypes.append(source.incomeType) }
    }

    public mutating func deleteSource(_ id: Int) {
        income.removeAll { $0.id == id }
    }

    public mutating func save(_ expense: Expense) {
        if let index = expenses.firstIndex(where: { $0.id == expense.id }) {
            expenses[index] = expense
            return
        }
        var added = expense
        added.id = nextId
        nextId += 1
        if added.cat == TrackerConstants.uncategorized {
            expenses.insert(added, at: 0)
        } else {
            let last = expenses.lastIndex { $0.cat == added.cat } ?? expenses.count - 1
            expenses.insert(added, at: last + 1)
        }
    }

    public mutating func deleteExpense(_ id: Int) {
        expenses.removeAll { $0.id == id }
    }

    public mutating func addCategory(_ name: String) {
        guard !name.isEmpty, !categories.contains(name) else { return }
        let used = Array(catColors.values)
        let pool = TrackerConstants.colorPool
        catColors[name] = pool.first { !used.contains($0) } ?? pool[categories.count % pool.count]
        categories.append(name)
    }

    public mutating func addIncomeType(_ name: String) {
        guard !name.isEmpty, !incomeTypes.contains(name) else { return }
        incomeTypes.append(name)
    }

    public mutating func setTaxPercent(_ percent: Double) {
        taxRate = min(0.99, max(0, percent / 100))
    }
}

/// Every derived number the budget screens show.
public struct TrackerSummary: Hashable, Sendable {
    public var gross = 0.0
    public var taxed = 0.0
    public var untaxed = 0.0
    /// Monthly take-home.
    public var earn = 0.0
    public var annualBonus = 0.0
    public var annualBonusNet = 0.0
    public var annualGross = 0.0
    public var afterTax = 0.0
    public var expenses = 0.0
    public var expenseCount = 0
    public var pureSavings = 0.0
    /// What is left of take-home after monthly expenses.
    public var game = 0.0
    public var byCategory: [String: Double] = [:]
    /// Two months of expenses for checking, six for an emergency fund.
    public var checkingGoal = 0.0
    public var emergencyGoal = 0.0

    public var savingsRate: Int {
        earn > 0 ? Int((game / earn * 100).rounded()) : 0
    }

    public var monthsToChecking: Int? {
        game > 0 ? Int((checkingGoal / game).rounded(.up)) : nil
    }

    public var monthsToEmergency: Int? {
        game > 0 ? Int((emergencyGoal / game).rounded(.up)) : nil
    }
}

public func summarize(_ data: TrackerData) -> TrackerSummary {
    var summary = TrackerSummary()
    let taxRate = data.taxRate
    summary.gross = data.income.reduce(0) { $0 + $1.monthlyGross }
    summary.taxed = data.income.filter(\.isTaxed).reduce(0) { $0 + $1.monthlyGross }
    summary.untaxed = data.income.filter { !$0.isTaxed }.reduce(0) { $0 + $1.monthlyGross }
    summary.earn = summary.taxed * (1 - taxRate) + summary.untaxed

    // A salaried source's `rate` is its annual bonus: annual figures only.
    func bonus(taxed: Bool) -> Double {
        data.income
            .filter { !$0.isHourly && $0.isTaxed == taxed && ($0.rate ?? 0) != 0 }
            .reduce(0) { $0 + ($1.rate ?? 0) }
    }
    let bonusTaxed = bonus(taxed: true)
    let bonusUntaxed = bonus(taxed: false)
    summary.annualBonus = bonusTaxed + bonusUntaxed
    summary.annualBonusNet = bonusTaxed * (1 - taxRate) + bonusUntaxed

    summary.annualGross = summary.gross * 12 + summary.annualBonus
    summary.afterTax = summary.earn * 12 + summary.annualBonusNet
    let counted = data.expenses.filter { $0.cat != TrackerConstants.uncategorized }
    summary.expenses = counted.reduce(0) { $0 + $1.monthlyCost }
    summary.expenseCount = counted.count
    summary.pureSavings = summary.afterTax - summary.expenses * 12
    summary.game = summary.earn - summary.expenses
    for expense in counted {
        summary.byCategory[expense.cat, default: 0] += expense.monthlyCost
    }
    summary.checkingGoal = summary.expenses * 2
    summary.emergencyGoal = summary.expenses * 6
    return summary
}

public func ordinalSuffix(_ n: Int) -> String {
    let suffixes = ["th", "st", "nd", "rd"]
    let v = n % 100
    let tens = (v - 20) % 10
    if tens >= 0, tens < suffixes.count { return suffixes[tens] }
    if v < suffixes.count { return suffixes[v] }
    return suffixes[0]
}

public func weekdaysLabel(_ weekdays: [Int]) -> String {
    let names = weekdays.compactMap { day -> String? in
        TrackerConstants.shortDays.indices.contains(day) ? TrackerConstants.shortDays[day] : nil
    }
    return names.isEmpty ? "-" : names.joined(separator: ", ")
}

public func datesLabel(_ dates: [Int]) -> String {
    dates.isEmpty ? "-" : dates.map { "\($0)\(ordinalSuffix($0))" }.joined(separator: ", ")
}

/// Accepts "pay.example.com" as https and rejects other schemes.
public func safeLink(_ text: String?) -> URL? {
    let value = (text ?? "").trimmingCharacters(in: .whitespaces)
    let lower = value.lowercased()
    if lower.hasPrefix("http:") || lower.hasPrefix("https:") || lower.hasPrefix("mailto:") {
        return URL(string: value)
    }
    let host = value.split(separator: "/").first ?? ""
    let isDomain =
        host.contains(".")
        && host.allSatisfy { $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" || $0 == "_" }
    return isDomain ? URL(string: "https://\(value)") : nil
}

/// "$1,235" rounded to whole dollars, or "$1,234.50" with cents.
public func formatUSD(_ value: Double, cents: Bool = false) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "USD"
    formatter.locale = Locale(identifier: "en_US")
    formatter.maximumFractionDigits = cents ? 2 : 0
    formatter.minimumFractionDigits = cents ? 2 : 0
    // Avoid "-$0" for tiny negative values that round to zero.
    let amount = !cents && value.rounded() == 0 ? 0 : value
    return formatter.string(from: NSNumber(value: amount)) ?? "$0"
}

/// Up to two decimals without trailing zeros: 1.5, 2, 0.25.
public func formatNumber(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.maximumFractionDigits = 2
    formatter.usesGroupingSeparator = true
    formatter.numberStyle = .decimal
    return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
}
