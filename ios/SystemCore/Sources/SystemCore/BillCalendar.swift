import Foundation

public struct CalendarPill: Identifiable, Hashable, Sendable {
    public enum Kind: Sendable { case pay, bill }

    public let id: String
    public let kind: Kind
    public let label: String
    public let color: String
    public let amount: Double
    /// Income source or expense id.
    public let refId: Int
    /// Where a payday came from when it moved off a weekend, like "1st".
    public let shiftLabel: String?
}

public struct CalendarMonth: Hashable, Sendable {
    public let daysInMonth: Int
    /// Weekday of the 1st (0 = Sunday).
    public let firstWeekday: Int
    public let pills: [Int: [CalendarPill]]
    /// Paydays minus bills, accumulated through each day (index = day).
    public let runningNet: [Double]
}

/// Pills and running totals for one month of the budget calendar.
public func buildCalendarMonth(
    _ data: TrackerData,
    year: Int,
    month: Int,
    showPaydays: Bool = true,
    showBills: Bool = true
) -> CalendarMonth {
    let first = CivilDate(year: year, month: month, day: 1)
    let daysInMonth = first.daysInMonth
    let days = Array(1...daysInMonth)
    func weekday(_ day: Int) -> Int { first.adding(days: day - 1).sundayIndex }

    // Weekend days move to the following Monday unless that leaves the month.
    func shiftWeekend(_ day: Int) -> Int {
        guard day >= 1, day <= daysInMonth else { return day }
        var current = day
        while weekday(current) == 0 || weekday(current) == 6 {
            current += 1
            if current > daysInMonth { return day }
        }
        return current
    }

    func payCount(_ source: IncomeSource) -> Int {
        let count =
            source.paydayIsWeekdays
            ? days.filter { source.paydayWeekdays.contains(weekday($0)) }.count
            : source.paydayDates.filter { $0 <= daysInMonth }.count
        return max(count, 1)
    }
    func payAmount(_ source: IncomeSource) -> Double {
        (source.monthlyNet(taxRate: data.taxRate) / Double(payCount(source))).rounded()
    }

    var dayNet = [Double](repeating: 0, count: daysInMonth + 1)
    func addNet(_ day: Int, _ amount: Double) {
        if day >= 1, day <= daysInMonth { dayNet[day] += amount }
    }
    var pills: [Int: [CalendarPill]] = [:]

    let bills = data.expenses.filter {
        $0.cat != TrackerConstants.uncategorized && $0.showOnCal
    }

    // Running net, independent of which pill types are shown.
    for source in data.income where source.showOnCal {
        let amount = payAmount(source)
        if source.paydayIsWeekdays {
            for day in days where source.paydayWeekdays.contains(weekday(day)) {
                addNet(shiftWeekend(day), amount)
            }
        } else {
            for day in source.paydayDates where day <= daysInMonth {
                addNet(shiftWeekend(day), amount)
            }
        }
    }
    for bill in bills {
        if bill.dueIsWeekdays {
            for day in days where bill.dueWeekdays.contains(weekday(day)) {
                addNet(day, -bill.cost)
            }
        } else if let due = bill.due {
            addNet(due, -bill.cost)
        }
    }
    var runningNet = [Double](repeating: 0, count: daysInMonth + 1)
    for day in days { runningNet[day] = runningNet[day - 1] + dayNet[day] }

    func add(
        _ day: Int, kind: CalendarPill.Kind, id: Int, from: Int, label: String, color: String, amount: Double,
        shift: String?
    ) {
        guard day >= 1, day <= daysInMonth else { return }
        let prefix = kind == .pay ? "pay" : "bill"
        pills[day, default: []].append(
            CalendarPill(
                id: "\(prefix)-\(id)-\(from)-\(day)", kind: kind, label: label, color: color,
                amount: amount, refId: id, shiftLabel: shift))
    }

    if showPaydays {
        for source in data.income where source.showOnCal {
            let amount = payAmount(source)
            if source.paydayIsWeekdays {
                for day in days {
                    let dow = weekday(day)
                    guard source.paydayWeekdays.contains(dow) else { continue }
                    let moved = shiftWeekend(day)
                    add(
                        moved, kind: .pay, id: source.id, from: dow, label: source.name,
                        color: TrackerConstants.paydayColor, amount: amount,
                        shift: moved != day ? TrackerConstants.shortDays[dow] : nil)
                }
            } else {
                for day in source.paydayDates where day <= daysInMonth {
                    let moved = shiftWeekend(day)
                    add(
                        moved, kind: .pay, id: source.id, from: day, label: source.name,
                        color: TrackerConstants.paydayColor, amount: amount,
                        shift: moved != day ? "\(day)\(ordinalSuffix(day))" : nil)
                }
            }
        }
    }

    // Bills are never shifted: they are due when they are due.
    if showBills {
        for bill in bills {
            let color = data.color(forCategory: bill.cat)
            if bill.dueIsWeekdays {
                for day in days where bill.dueWeekdays.contains(weekday(day)) {
                    add(
                        day, kind: .bill, id: bill.id, from: weekday(day), label: bill.name,
                        color: color, amount: bill.cost, shift: nil)
                }
            } else if let due = bill.due {
                add(
                    due, kind: .bill, id: bill.id, from: due, label: bill.name, color: color,
                    amount: bill.cost, shift: nil)
            }
        }
    }

    return CalendarMonth(
        daysInMonth: daysInMonth,
        firstWeekday: first.sundayIndex,
        pills: pills,
        runningNet: runningNet)
}

/// How much of the month's play money has landed. Paychecks cover the month's
/// expenses first, so `soFar` stays at zero until they have, then climbs to
/// `game` with the last payday.
public struct MonthProgress: Hashable, Sendable {
    public let soFar: Double
    public let toCome: Double
    /// What's left of the month's expenses for paychecks to cover.
    public let toCover: Double
}

public func monthProgress(_ data: TrackerData, on date: CivilDate) -> MonthProgress {
    let summary = summarize(data)
    let game = max(summary.game, 0)
    let paid = paidThrough(date, data)
    let soFar = min(max(paid - summary.expenses, 0), game)
    return MonthProgress(soFar: soFar, toCome: game - soFar, toCover: max(summary.expenses - paid, 0))
}

/// Take-home paid from the 1st through `date`.
private func paidThrough(_ date: CivilDate, _ data: TrackerData) -> Double {
    // The calendar leaves out two things that still get paid: sources hidden
    // from it, and a payday on the 31st in a shorter month.
    var paid = data
    for index in paid.income.indices {
        paid.income[index].showOnCal = true
        paid.income[index].paydayDates = paid.income[index].paydayDates.map { min($0, date.daysInMonth) }
    }
    let month = buildCalendarMonth(paid, year: date.year, month: date.month, showBills: false)
    return (1...date.day).flatMap { month.pills[$0] ?? [] }.reduce(0) { $0 + $1.amount }
}
