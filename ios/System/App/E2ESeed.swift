import Foundation
import SystemCore

/// Made-up data for UI tests and screenshots (`-e2e`), so they never need a
/// real account.
enum E2ESeed {
    static func backend() -> MemoryBackend {
        let signedOut = ProcessInfo.processInfo.arguments.contains("-signedOut")
        return MemoryBackend(
            documents: [
                "schedule": schedule.toJSON(),
                "game_tracker": tracker.toJSON(),
            ],
            signedInAs: signedOut ? nil : "e2e@example.com")
    }

    static let testAlertId = "e2e-alert"

    /// `-testAlert` adds an alert that fires at the next minute, so a UI test
    /// can watch a real notification arrive and press its buttons.
    static func extraAlerts(today: CivilDate, plan: DayPlan) -> [PlannedAlert] {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-e2e"), arguments.contains("-testAlert"),
            let running = plan.blocks.first(where: { $0.label == "work" }),
            let next = plan.blocks.first(where: { $0.label == "gym" })
        else { return [] }
        let seconds = Calendar.current.component(.second, from: Date())
        let wait = 60 - seconds + (seconds > 50 ? 60 : 0)
        return [
            PlannedAlert(
                id: testAlertId,
                kind: .startingSoon,
                date: today,
                fireDate: Date().addingTimeInterval(TimeInterval(wait)),
                title: "gym in 5 min",
                body: "Wrap up work",
                skipBlockId: next.id,
                extendBlockId: running.id)
        ]
    }

    private static var schedule: Schedule {
        var week = Schedule.empty
        func add(_ day: Int, _ start: Int, _ end: Int, _ label: String, _ color: String) {
            week.save(Block(id: 0, day: day, start: start, end: end, label: label, color: color))
        }
        for day in 0..<5 {
            add(day, 2, 4, "Block", "#888780")
            add(day, 5, 21, "work", "#5aab3f")
            add(day, 21, 23, "gym", "#378ADD")
            add(day, 24, 28, "tutoring", "#E24B4A")
            add(day, 30, 32, "study", "#7F77DD")
        }
        add(5, 6, 14, "errands", "#f07830")
        add(5, 18, 22, "tutoring Ana", "#E24B4A")
        add(6, 8, 12, "church", "#e8c323")
        add(6, 20, 26, "family", "#1abc9c")
        // `-nowBlock` puts something on at the real time, because the widget
        // runs on the real clock rather than `-nowAt`.
        if ProcessInfo.processInfo.arguments.contains("-nowBlock") {
            let now = Date()
            let slot = (CivilDate.minuteOfDay(now) - ScheduleGrid.firstHour * 60) / 30
            add(CivilDate(now).mondayIndex, slot, slot + 2, "focus", "#E24B4A")
            add(CivilDate(now).mondayIndex, slot + 2, slot + 3, "review", "#7F77DD")
        }
        return week
    }

    private static var tracker: TrackerData {
        var data = TrackerData(
            taxRate: 0.25,
            income: [
                IncomeSource(
                    id: 1, name: "Day job", incomeType: "Work", monthly: 4000, paydayDates: [1, 15]),
                IncomeSource(
                    id: 2, name: "Tutoring", incomeType: "Side", isTaxed: false, isHourly: true,
                    monthly: nil, rate: 40, hrsPerWeek: 6, paydayIsWeekdays: true, paydayWeekdays: [5]),
            ],
            incomeTypes: ["Work", "Side"],
            categories: ["Bills", "Everyday", "Fun"],
            catColors: ["Bills": "#378ADD", "Everyday": "#1D9E75", "Fun": "#7F77DD"],
            expenses: [
                Expense(id: 10, name: "Rent", cat: "Bills", cost: 900, due: 1, paymentLink: "pay.example.com"),
                Expense(id: 11, name: "Car", cat: "Bills", cost: 250, due: 12),
                Expense(id: 12, name: "Insurance", cat: "Bills", cost: 110, due: 3),
                Expense(id: 13, name: "Groceries", cat: "Everyday", cost: 300),
                Expense(id: 14, name: "Gas", cat: "Everyday", cost: 90),
                Expense(id: 15, name: "Eating out", cat: "Fun", cost: 120),
                Expense(id: 16, name: "Music", cat: "Fun", cost: 12, due: 20),
            ],
            nextId: 30)
        // `-uncategorized` adds what the website leaves when a category is deleted.
        if ProcessInfo.processInfo.arguments.contains("-uncategorized") {
            data.expenses.append(Expense(id: 17, name: "Mystery", cat: TrackerConstants.uncategorized, cost: 75))
        }
        // `-emptyBudget` is a brand new account.
        return ProcessInfo.processInfo.arguments.contains("-emptyBudget") ? .empty : data
    }
}
