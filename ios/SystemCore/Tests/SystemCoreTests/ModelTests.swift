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

@Suite struct PlayingWithTests {
    /// $4,000 a month with no tax, half on the 1st and half on the 15th, against
    /// $1,500 of expenses. November 1, 2026 is a Sunday, November 15 too.
    var data: TrackerData {
        TrackerData(
            taxRate: 0,
            income: [IncomeSource(id: 1, name: "Job", incomeType: "Work", monthly: 4000, paydayDates: [2, 16])],
            incomeTypes: ["Work"],
            categories: ["Home"],
            catColors: [:],
            expenses: [
                Expense(id: 2, name: "Rent", cat: "Home", cost: 1000, due: 1),
                Expense(id: 3, name: "Food", cat: "Home", cost: 500),
            ],
            nextId: 10)
    }

    private func november(_ day: Int) -> CivilDate {
        CivilDate(year: 2026, month: 11, day: day)
    }

    @Test func expensesSplitIntoBillsAndTheRest() {
        var budget = data
        budget.expenses.append(Expense(id: 4, name: "Gym", cat: "Home", cost: 10, dueIsWeekdays: true, dueWeekdays: [1]))
        let summary = summarize(budget)
        #expect(abs(summary.bills - (1000 + 10 * TrackerConstants.weeksPerMonth)) < 0.0001)
        #expect(summary.otherExpenses == 500)
        #expect(abs(summary.bills + summary.otherExpenses - summary.expenses) < 0.0001)
    }

    @Test func uncategorizedExpensesAreCalledOutButNotCounted() {
        var budget = data
        budget.expenses.append(Expense(id: 4, name: "Mystery", cat: TrackerConstants.uncategorized, cost: 75))
        let summary = summarize(budget)
        #expect(summary.uncategorized == 75)
        #expect(summary.expenses == 1500)
        #expect(summary.game == 2500)
    }

    @Test func nothingLandsBeforeTheFirstPayday() {
        #expect(monthProgress(data, on: november(1)) == MonthProgress(soFar: 0, toCome: 2500, toCover: 1500))
    }

    @Test func payCoversTheMonthsExpensesFirst() {
        // $2,000 paid, $1,500 of it spoken for, wherever the due dates fall.
        #expect(monthProgress(data, on: november(2)) == MonthProgress(soFar: 500, toCome: 2000, toCover: 0))
        #expect(monthProgress(data, on: november(15)) == MonthProgress(soFar: 500, toCome: 2000, toCover: 0))
    }

    @Test func aPaycheckThatDoesNotCoverExpensesLandsNothing() {
        var budget = data
        budget.expenses[1].cost = 1500
        #expect(monthProgress(budget, on: november(2)) == MonthProgress(soFar: 0, toCome: 1500, toCover: 500))
    }

    @Test func theLastPaydayBringsInAllOfIt() {
        #expect(monthProgress(data, on: november(16)) == MonthProgress(soFar: 2500, toCome: 0, toCover: 0))
        #expect(monthProgress(data, on: november(30)) == MonthProgress(soFar: 2500, toCome: 0, toCover: 0))
    }

    @Test func aWeekendPaydayCountsWhenTheMoneyArrives() {
        var budget = data
        budget.income[0].paydayDates = [1, 15]
        #expect(monthProgress(budget, on: november(1)).soFar == 0)
        #expect(monthProgress(budget, on: november(2)).soFar == 500)
    }

    @Test func aSourceHiddenFromTheCalendarStillPays() {
        var budget = data
        budget.income[0].showOnCal = false
        #expect(monthProgress(budget, on: november(16)).soFar == 2500)
    }

    @Test func aPaydayOnThe31stStillLandsInAShorterMonth() {
        var budget = data
        budget.income[0].paydayDates = [31]
        #expect(monthProgress(budget, on: november(27)).soFar == 0)
        #expect(monthProgress(budget, on: november(30)).soFar == 2500)
    }

    @Test func roundedPaychecksNeverLandMoreThanTheTotal() {
        var budget = data
        budget.income[0].monthly = 4001
        budget.income[0].paydayDates = [3, 10, 17]
        let end = monthProgress(budget, on: november(30))
        #expect(end.soFar == 2501)
        #expect(end.toCome == 0)
    }

    @Test func aBudgetThatRunsOverHasNothingToLand() {
        var budget = data
        budget.expenses[0].cost = 9000
        #expect(monthProgress(budget, on: november(30)) == MonthProgress(soFar: 0, toCome: 0, toCover: 5500))
    }

    @Test func anEmptyBudgetIsAllZeros() {
        #expect(monthProgress(.empty, on: november(30)) == MonthProgress(soFar: 0, toCome: 0, toCover: 0))
    }
}
