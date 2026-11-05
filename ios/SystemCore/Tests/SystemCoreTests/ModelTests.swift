import Foundation
import Testing

@testable import SystemCore

@Suite struct JSONValueTests {
    @Test func mergingKeepsFieldsThisAppDoesNotModel() {
        let cloud: JSONValue = ["known": 1, "fromTheWeb": "keep", "nested": ["a": 1, "b": 2]]
        let saved = (["known": 2, "nested": ["a": 9]] as JSONValue).merged(over: cloud)
        #expect(saved == ["known": 2, "fromTheWeb": "keep", "nested": ["a": 9, "b": 2]])
    }

    @Test func listsKeepTheAppsOrderAndEachItemsUnknownFields() {
        let cloud: JSONValue = ["items": [["id": 1, "x": "one"], ["id": 2, "x": "two"], ["id": 3, "x": "gone"]]]
        let local: JSONValue = ["items": [["id": 2, "y": 2], ["id": 1, "y": 1], ["id": 9, "y": 9]]]
        #expect(
            local.merged(over: cloud)
                == ["items": [["id": 2, "x": "two", "y": 2], ["id": 1, "x": "one", "y": 1], ["id": 9, "y": 9]]])
    }

    @Test func replacedKeysDropDeletedEntries() {
        let cloud: JSONValue = ["colors": ["old": "#111111", "kept": "#222222"]]
        let local: JSONValue = ["colors": ["kept": "#222222"]]
        #expect(local.merged(over: cloud, replacing: ["colors"]) == local)
    }

    @Test func numbersCanComeFromOldNumericStrings() {
        #expect(JSONValue.string("1.5").doubleValue == 1.5)
        #expect(JSONValue.string(" 2 ").intValue == 2)
        #expect(JSONValue.string("abc").doubleValue == nil)
        #expect(JSONValue.null.doubleValue == nil)
    }
}

@Suite struct FirestoreCodingTests {
    @Test func roundTripsEveryKindOfValue() {
        let value: JSONValue = [
            "whole": 700, "fraction": 0.25, "text": "hi", "flag": true, "nothing": nil,
            "list": [1, "two", [3]], "map": ["a": ["b": 1.5]], "emptyList": [], "emptyMap": [:],
        ]
        let typed = FirestoreCoding.encode(value)
        #expect(FirestoreCoding.decode(typed) == value)
    }

    @Test func wholeNumbersGoUpAsIntegersLikeTheWebsitesSDK() {
        #expect(FirestoreCoding.encode(700) == ["integerValue": "700"])
        #expect(FirestoreCoding.encode(0.25) == ["doubleValue": 0.25])
    }

    @Test func readsWhatFirestoreSends() {
        let typed: JSONValue = [
            "mapValue": [
                "fields": [
                    "a": ["integerValue": "12"],
                    "b": ["arrayValue": [:]],
                    "c": ["mapValue": [:]],
                    "d": ["timestampValue": "2026-11-05T10:00:00Z"],
                ]
            ]
        ]
        #expect(FirestoreCoding.decode(typed) == ["a": 12, "b": [], "c": [:], "d": "2026-11-05T10:00:00Z"])
    }
}

@Suite struct ScheduleModelTests {
    @Test func savingANewBlockAssignsAnIdAndRemembersTheColor() {
        var week = Schedule.empty
        week.save(Block(id: 0, day: 3, start: 0, end: 2, label: "gym", color: "#378ADD"))
        week.save(Block(id: 0, day: 3, start: 2, end: 4, label: "work", color: "#E24B4A"))
        #expect(week.blocks.map(\.id) == [1, 2])
        #expect(week.nextId == 3)
        #expect(week.selColor == "#E24B4A")
    }

    @Test func savingAnEditTrimsWhatItCovers() {
        var week = schedule(block(1, 0, 0, 8, "long"), block(2, 0, 10, 12, "short"))
        week.save(block(2, 0, 2, 4, "short"))
        #expect(week.blocks.map(\.id) == [1, 100, 2])
        #expect(week.blocks.first { $0.id == 100 }?.start == 4)
    }

    @Test func survivesMissingAndOddFields() {
        let revived = Schedule(json: [
            "blocks": [["id": 1, "day": 0, "start": 0, "end": "2"], ["id": 2]], "nextId": 0,
        ])!
        #expect(revived.blocks.count == 1)
        #expect(revived.blocks[0].label == "Block")
        #expect(revived.blocks[0].end == 2)
        #expect(revived.nextId == 2)
        #expect(Schedule(json: nil) == nil)
    }

    @Test func roundTripsThroughJSON() {
        let week = schedule(block(1, 0, 0, 8, "a"), block(2, 6, 10, 12, "b"))
        #expect(Schedule(json: week.toJSON()) == week)
    }
}

@Suite struct TrackerModelTests {
    @Test func toleratesTheWebsitesOldShapes() {
        let data = TrackerData(json: [
            "income": [["id": 1, "name": "Old", "payday": "1st & 15th", "rate": 20, "monthly": nil]],
            "expenses": [["id": 2, "name": "Rent", "cost": "900"]],
        ])!
        #expect(data.income[0].paydayDates == [1, 15])
        #expect(data.income[0].isHourly)
        #expect(data.income[0].incomeType == "Other")
        #expect(data.incomeTypes == ["Other"])
        #expect(data.expenses[0].cost == 900)
        #expect(data.expenses[0].cat == "Uncategorized")
        #expect(data.expenses[0].showOnCal)
    }

    @Test func savingKeepsExpensesWithTheirCategory() {
        var data = TrackerData.empty
        data.addCategory("Fixed")
        data.addCategory("Flex")
        data.save(Expense(id: 0, name: "a", cat: "Fixed", cost: 1))
        data.save(Expense(id: 0, name: "b", cat: "Flex", cost: 1))
        data.save(Expense(id: 0, name: "c", cat: "Fixed", cost: 1))
        data.save(Expense(id: 0, name: "d", cat: "Uncategorized", cost: 1))
        #expect(data.expenses.map(\.name) == ["d", "a", "c", "b"])
        #expect(Set(data.expenses.map(\.id)).count == 4)
    }

    @Test func newCategoriesPickAnUnusedColor() {
        var data = TrackerData.empty
        data.addCategory("A")
        data.addCategory("B")
        #expect(data.catColors["A"] != data.catColors["B"])
        data.addCategory("A")
        #expect(data.categories == ["A", "B"])
    }

    @Test func taxPercentStaysInRange() {
        var data = TrackerData.empty
        data.setTaxPercent(120)
        #expect(data.taxRate == 0.99)
        data.setTaxPercent(-5)
        #expect(data.taxRate == 0)
    }

    @Test func formatsMoneyLikeTheWebsite() {
        #expect(formatUSD(1234.5) == "$1,234")
        #expect(formatUSD(1234.5, cents: true) == "$1,234.50")
        #expect(formatUSD(-0.2) == "$0")
        #expect(formatUSD(-1200) == "-$1,200")
        #expect(formatNumber(1.5) == "1.5")
        #expect(formatNumber(2) == "2")
    }
}

@Suite struct PaymentReportTests {
    var report: PaymentReport {
        PaymentReport(
            name: "T", start: "", end: "", rate: 30, every: "",
            students: [Student(id: 1, name: "Sam", subject: "Algebra"), Student(id: 2, name: "Ann", subject: "Geometry")],
            nextId: 10)
    }

    @Test func addingASessionTakesTheNextId() {
        var r = report
        r.save(TutoringSession(id: 0, date: "2026-11-05", startTime: "18:00", hrs: 2), studentId: 2)
        #expect(r.students[1].sessions.map(\.id) == [10])
        #expect(r.nextId == 11)
        #expect(r.total == 60)
    }

    @Test func labelsNamingAStudentCountAsTutoring() {
        #expect(report.student(matching: "Sam Algebra")?.id == 1)
        #expect(report.isTutoring("sam"))
        #expect(report.isTutoring("Tutoring"))
        #expect(!report.isTutoring("work"))
        #expect(report.student(matching: "Tutoring") == nil)
    }

    @Test func keepsTheWebsitesFieldsThroughJSON() {
        var r = report
        r.save(TutoringSession(id: 0, date: "2026-11-05", startTime: "18:00", hrs: 1.5), studentId: 1)
        #expect(PaymentReport(json: r.toJSON()) == r)
    }
}

@Suite struct SpendingTests {
    @Test func parsesWhatShortcutsHandsOver() {
        #expect(parseAmount("$12.34") == 12.34)
        #expect(parseAmount("12.34 USD") == 12.34)
        #expect(parseAmount("$1,234.50") == 1234.5)
        #expect(parseAmount("1.234,50") == 1234.5)
        #expect(parseAmount("12,34") == 12.34)
        #expect(parseAmount("1,234") == 1234)
        #expect(parseAmount("7") == 7)
        #expect(parseAmount("") == nil)
        #expect(parseAmount("free") == nil)
        #expect(parseAmount("$0.00") == nil)
    }

    @Test func monthsGetTheirOwnDocument() {
        #expect(SpendingMonth.pageId(thursday) == "spending_2026_11")
    }

    @Test func roundTripsThroughJSON() {
        let date = Date(timeIntervalSince1970: 1_793_000_000)
        let month = SpendingMonth(entries: [
            SpendEntry(id: "a", date: date, amount: 12.5, merchant: "Cafe", category: "Fun", source: .applePay),
            SpendEntry(id: "b", date: date, amount: 3, merchant: "Bus"),
        ])
        #expect(SpendingMonth(json: month.toJSON()) == month)
    }

    @Test func catchesADoubleFiredAutomation() {
        let date = Date(timeIntervalSince1970: 1_793_000_000)
        let month = SpendingMonth(entries: [
            SpendEntry(date: date, amount: 12.5, merchant: "Cafe", source: .applePay)
        ])
        #expect(month.hasDuplicate(amount: 12.5, merchant: "cafe", near: date.addingTimeInterval(30)))
        #expect(!month.hasDuplicate(amount: 12.5, merchant: "cafe", near: date.addingTimeInterval(90)))
        #expect(!month.hasDuplicate(amount: 9, merchant: "cafe", near: date))
    }

    @Test func thePlanOnlyCountsExpensesWithNoDueDate() {
        var data = TrackerData.empty
        data.addCategory("Flex")
        data.save(Expense(id: 0, name: "Rent", cat: "Flex", cost: 900, due: 1))
        data.save(Expense(id: 0, name: "Food", cat: "Flex", cost: 300))
        data.save(Expense(id: 0, name: "Review", cat: "Uncategorized", cost: 50))
        #expect(FlexiblePlan(data).byCategory == ["Flex": 300])
        #expect(FlexiblePlan(data).total == 300)
    }
}
