import XCTest

final class BudgetTests: AppTestCase {
    private func openBudget() {
        launch()
        openTab("Budget")
    }

    func testThePagesAreOverviewIncomeExpensesAndCalendar() {
        openBudget()
        let page = element("budget.page")
        XCTAssertTrue(page.waitForExistence(timeout: 8))
        XCTAssertEqual(
            page.buttons.allElementsBoundByIndex.map(\.label), ["Overview", "Income", "Expenses", "Calendar"])
    }

    func testOverviewAddsUpWhatYouArePlayingWith() {
        openBudget()
        // $4,000 salary + $40 x 6 hrs x 4 weeks = $4,960 gross.
        expect("overview.gross", "$4,960")
        // 25% of the salary. The side income isn't taxed.
        expect("overview.taxes", "-$1,000")
        expect("overview.bills", "-$1,272")
        expect("overview.other", "-$510")
        expect("overview.game", "$2,178")
        XCTAssertFalse(element("overview.uncategorized").exists)
        snapshot("budget-overview")
    }

    func testPayCoversExpensesBeforeAnyOfItLands() {
        openBudget()
        // Only the first $1,500 paycheck is in, against $1,782 of expenses.
        expect("overview.soFar", "$282 of expenses to cover")
        expect("overview.toCome", "$2,178 to come")
    }

    func testMoneyLandsOncePaychecksCoverTheMonth() {
        launch(at: "2026-11-16T09:00")
        openTab("Budget")
        // Two $1,500 paychecks and two $240 ones, less $1,782 of expenses.
        expect("overview.soFar", "$1,698 so far this month")
        expect("overview.toCome", "$480 to come")
        snapshot("budget-overview-midmonth")
    }

    func testTheLastPaydayBringsInAllOfIt() {
        launch(at: "2026-11-27T09:00")
        openTab("Budget")
        expect("overview.soFar", "$2,178 so far this month")
        expect("overview.toCome", "$0 to come")
    }

    func testSpendingMoreThanYouMakeShowsWhatYouAreShort() {
        openBudget()
        pick("Expenses", in: "budget.page")
        tap("expense.Rent")
        let cost = element("expense.cost")
        XCTAssertTrue(cost.waitForExistence(timeout: 5))
        replaceText(of: cost, with: "9000")
        tap("expense.save")
        pick("Overview", in: "budget.page")
        expect("overview.game", "-$5,922")
        XCTAssertFalse(element("overview.soFar").exists)
        snapshot("budget-overview-over")
    }

    func testAnExpenseWithNoCategoryIsCalledOut() {
        launch("-uncategorized")
        openTab("Budget")
        expect("overview.uncategorized", "$75 with no category isn't counted")
        expect("overview.game", "$2,178")
        snapshot("budget-overview-uncategorized")
    }

    func testABrandNewBudgetIsEmptyNotBroken() {
        launch("-emptyBudget")
        openTab("Budget")
        expect("overview.game", "$0")
        XCTAssertFalse(element("overview.soFar").exists)
        snapshot("budget-overview-empty")
    }

    func testExpenseAmountsAreOnScreenWithoutSwiping() {
        openBudget()
        pick("Expenses", in: "budget.page")
        let amount = element("expense.amount.Rent")
        XCTAssertTrue(amount.waitForExistence(timeout: 8))
        expect("expense.amount.Rent", "$900")
        XCTAssertTrue(isOnScreen(amount), "The cost should not need a sideways swipe")
        snapshot("budget-expenses")
    }

    func testIncomeAmountsAreOnScreenWithoutSwiping() {
        openBudget()
        pick("Income", in: "budget.page")
        let amount = element("income.amount.Day job")
        XCTAssertTrue(amount.waitForExistence(timeout: 8))
        expect("income.amount.Day job", "$4,000")
        XCTAssertTrue(isOnScreen(amount))
        snapshot("budget-income")
    }

    func testBillCalendarFitsAllSevenDays() {
        openBudget()
        pick("Calendar", in: "budget.page")
        for key in ["2026-11-01", "2026-11-07"] {
            XCTAssertTrue(element("bills.\(key)").waitForExistence(timeout: 8), key)
            XCTAssertTrue(isOnScreen(element("bills.\(key)")), "\(key) is off screen")
        }
        snapshot("budget-calendar")
        tap("bills.2026-11-12")
        XCTAssertTrue(app.staticTexts["Car"].waitForExistence(timeout: 5))
        snapshot("budget-calendar-day")
    }

    func testEditingAnExpenseUpdatesTheTotals() {
        openBudget()
        pick("Expenses", in: "budget.page")
        tap("expense.Rent")
        let cost = element("expense.cost")
        XCTAssertTrue(cost.waitForExistence(timeout: 5))
        replaceText(of: cost, with: "1000")
        snapshot("expense-editor")
        // Straight to Save, with the field still focused.
        tap("expense.save")
        expect("expense.amount.Rent", "$1,000")
        expect("expenses.total", "Total per month, $1,882")
    }
}
