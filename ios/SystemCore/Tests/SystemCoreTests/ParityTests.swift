import Foundation
import Testing

@testable import SystemCore

/// `Fixtures/parity.json` is the output of the website's own TypeScript run on
/// made-up data, so these prove the app and the site compute the same numbers.
private let fixture: JSONValue = {
    let url = Bundle.module.url(forResource: "parity", withExtension: "json", subdirectory: "Fixtures")!
    return try! JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: url))
}()

private func blocks(_ json: JSONValue?) -> [Block] {
    Schedule(json: ["blocks": json ?? [], "nextId": 1000])!.blocks
}

private func close(_ a: Double, _ b: Double) -> Bool {
    abs(a - b) < 0.000001
}

@Suite struct TrackerParity {
    let data = TrackerData(json: fixture["tracker"]!["input"]!)!

    @Test func summaryMatchesTheWebsite() {
        let expected = fixture["tracker"]!["summary"]!
        let s = summarize(data)
        let pairs: [(String, Double)] = [
            ("gross", s.gross), ("taxed", s.taxed), ("untaxed", s.untaxed), ("earn", s.earn),
            ("annualBonus", s.annualBonus), ("annualBonusNet", s.annualBonusNet),
            ("annualGross", s.annualGross), ("afterTax", s.afterTax), ("expenses", s.expenses),
            ("pureSavings", s.pureSavings), ("game", s.game), ("checkingGoal", s.checkingGoal),
            ("emergencyGoal", s.emergencyGoal),
        ]
        for (key, value) in pairs {
            #expect(close(value, expected[key]!.doubleValue!), "\(key)")
        }
        #expect(s.expenseCount == expected["expenseCount"]!.intValue)
        #expect(
            s.byCategory.mapValues { ($0 * 100).rounded() }
                == expected["byCategory"]!.objectValue!.mapValues { ($0.doubleValue! * 100).rounded() })
    }

    @Test func expenseCostsAndLabelsMatchTheWebsite() {
        let costs = fixture["tracker"]!["monthlyCosts"]!.arrayValue!.map(\.doubleValue!)
        for (expense, cost) in zip(data.expenses, costs) { #expect(close(expense.monthlyCost, cost)) }
        let labels = fixture["tracker"]!["dueLabels"]!.arrayValue!.map(\.stringValue!)
        #expect(data.expenses.map(\.dueLabel) == labels)
    }

    @Test func calendarMatchesTheWebsiteAcrossMonths() {
        let months = fixture["tracker"]!["months"]!.arrayValue!
        #expect(months.count == 14)
        for expected in months {
            let year = expected["year"]!.intValue!
            let month = expected["month"]!.intValue!
            let built = buildCalendarMonth(data, year: year, month: month)
            #expect(built.firstWeekday == expected["firstWeekday"]!.intValue)
            #expect(built.daysInMonth == expected["daysInMonth"]!.intValue)
            let net = expected["runningNet"]!.arrayValue!.map(\.doubleValue!)
            #expect(built.runningNet.count == net.count)
            for (a, b) in zip(built.runningNet, net) { #expect(close(a, b), "\(year)-\(month)") }

            let days = expected["pills"]!.objectValue!
            #expect(Set(built.pills.keys.map(String.init)) == Set(days.keys))
            for (day, pills) in days {
                let want = pills.arrayValue!
                let got = built.pills[Int(day)!]!
                #expect(got.map(\.id) == want.map { $0["id"]!.stringValue! }, "\(year)-\(month)-\(day)")
                #expect(got.map(\.label) == want.map { $0["label"]!.stringValue! })
                #expect(got.map(\.color) == want.map { $0["color"]!.stringValue! })
                #expect(got.map(\.shiftLabel) == want.map { $0["shiftLabel"]!.stringValue })
                for (pill, raw) in zip(got, want) {
                    #expect(close(pill.amount, raw["amount"]!.doubleValue!))
                }
            }
        }
    }

    @Test func filtersHidePillsButKeepTheRunningNet() {
        let all = buildCalendarMonth(data, year: 2026, month: 10)
        let bills = buildCalendarMonth(data, year: 2026, month: 10, showPaydays: false)
        #expect(!bills.pills.values.flatMap { $0 }.contains { $0.kind == .pay })
        #expect(bills.runningNet == all.runningNet)
    }

    @Test func linksMatchTheWebsite() {
        for (input, output) in fixture["links"]!.objectValue! {
            let want = output.stringValue
            #expect(safeLink(input)?.absoluteString == want, "\(input)")
        }
    }

    @Test func labelsMatchTheWebsite() {
        #expect(datesLabel([1, 2, 3, 4, 11, 12, 13, 21, 22, 23, 31]) == fixture["labels"]!["dates"]!.stringValue)
        #expect(weekdaysLabel([0, 3, 6]) == fixture["labels"]!["weekdays"]!.stringValue)
    }
}

@Suite struct ScheduleParity {
    let schedule = fixture["schedule"]!

    @Test func slotLabelsMatchTheWebsite() {
        let labels = [0, 1, 11, 12, 13, 35, 36].map(ScheduleGrid.slotLabel)
        #expect(labels == schedule["slotLabels"]!.arrayValue!.map(\.stringValue!))
    }

    @Test func revivingRepairsOverlapsLikeTheWebsite() {
        let case_ = schedule["revive"]!
        let revived = Schedule(json: case_["input"]!)!
        #expect(revived.blocks == blocks(case_["output"]!["blocks"]))
        #expect(revived.nextId == case_["output"]!["nextId"]!.intValue)
    }

    @Test func revivingShiftsOldGridsLikeTheWebsite() {
        let case_ = schedule["shifted"]!
        let revived = Schedule(json: case_["input"]!)!
        #expect(revived.blocks == blocks(case_["output"]!["blocks"]))
        #expect(revived.hStart == 6)
    }

    @Test func placingMatchesTheWebsite() {
        let a = Block(id: 1, day: 0, start: 0, end: 12, label: "A", color: "#111111")
        let d = Block(id: 4, day: 1, start: 10, end: 20, label: "D", color: "#444444")
        let e = Block(id: 5, day: 1, start: 12, end: 14, label: "E", color: "#555555")
        let n = Block(id: 7, day: 0, start: 4, end: 6, label: "N", color: "#777777")
        let inside = placeBlock([a], block: n, nextId: 8)
        #expect(inside.blocks == blocks(schedule["inside"]!["blocks"]))
        #expect(inside.nextId == schedule["inside"]!["nextId"]!.intValue)

        let cover = Block(id: 7, day: 1, start: 8, end: 30, label: "N", color: "#777777")
        let covering = placeBlock([d, e], block: cover, nextId: 8)
        #expect(covering.blocks == blocks(schedule["covering"]!["blocks"]))
    }
}

@Suite struct ReportParity {
    @Test func hoursAndTotalsMatchTheWebsite() {
        let expected = fixture["report"]!
        let report = PaymentReport(json: [
            "rate": "30",
            "students": [
                [
                    "id": 1, "name": "S", "subject": "X",
                    "sessions": [
                        ["id": 2, "date": "2026-01-02", "hrs": "1.5"],
                        ["id": 3, "date": "2026-01-03", "startTime": "10:00", "hrs": 2],
                    ],
                ]
            ],
        ])!
        #expect(report.hours == expected["hours"]!.doubleValue)
        #expect(report.total == expected["total"]!.doubleValue)
        #expect(report.students.map(\.hours) == expected["studentHours"]!.arrayValue!.map(\.doubleValue!))
        #expect(shortDate("2026-05-02") == expected["short"]!.stringValue)
        #expect(["10:00", "00:30", "23:15"].map(clockTime) == expected["clock"]!.arrayValue!.map(\.stringValue!))
    }
}
