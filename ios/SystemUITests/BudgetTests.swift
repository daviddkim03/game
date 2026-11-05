import XCTest

final class BudgetTests: AppTestCase {
    private func openBudget() {
        launch()
        openTab("Budget")
    }

    func testOverviewMatchesTheSeedData() {
        openBudget()
        // $4,000 salary + $40 x 6 hrs x 4 weeks = $4,960 gross.
        expect("kpi.Monthly gross", "$4,960")
        expect("kpi.Take-home", "$3,960")
        expect("kpi.Monthly expenses", "$1,782")
        expect("kpi.GAME", "$2,178")
        snapshot("budget-overview")
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

    func testLoggingSpendingUpdatesTheMonth() {
        openBudget()
        pick("Spending", in: "budget.page")
        tap("budget.add")
        let amount = element("spend.amount")
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.typeText("12.50")
        let merchant = element("spend.merchant")
        merchant.tap()
        merchant.typeText("Cafe")
        snapshot("spend-editor")
        tap("spend.save")
        expect("spending.total", "$12.50")
        XCTAssertTrue(element("spend.Cafe").waitForExistence(timeout: 5))
        snapshot("budget-spending")

        pick("Overview", in: "budget.page")
        let spent = element("overview.spent")
        XCTAssertTrue(spent.waitForExistence(timeout: 5))
        XCTAssertEqual(spent.label, "$12")
    }

    func testApplePayActionLogsOncePerPurchase() {
        launch("-applePay")
        openTab("Budget")
        pick("Spending", in: "budget.page")
        // The action ran twice, as a double-fired automation would.
        expect("spending.total", "$12.34")
        XCTAssertTrue(element("spend.Blue Bottle").waitForExistence(timeout: 5))
        snapshot("budget-applepay")
    }

    func testAmountTypedThenSavedDirectlyIsNotLost() {
        openBudget()
        pick("Spending", in: "budget.page")
        tap("budget.add")
        let amount = element("spend.amount")
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.typeText("7.25")
        tap("spend.save")
        expect("spending.total", "$7.25")
    }

    func testPickingACategoryIsRememberedForThatMerchant() {
        openBudget()
        pick("Spending", in: "budget.page")
        for pass in 0..<2 {
            tap("budget.add")
            let amount = element("spend.amount")
            XCTAssertTrue(amount.waitForExistence(timeout: 5))
            amount.typeText("5")
            let merchant = element("spend.merchant")
            merchant.tap()
            merchant.typeText("Corner Shop")
            if pass == 0 {
                tap("spend.category")
                app.buttons["Fun"].firstMatch.tap()
            }
            tap("spend.save")
            XCTAssertTrue(element("spend.Corner Shop").waitForExistence(timeout: 5))
        }
        let picks = app.staticTexts.matching(NSPredicate(format: "label == 'Pick a category'"))
        XCTAssertEqual(picks.count, 0)
    }
}
