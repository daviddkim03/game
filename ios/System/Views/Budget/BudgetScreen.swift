import SwiftUI
import SystemCore

enum BudgetPage: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case income = "Income"
    case expenses = "Expenses"
    case calendar = "Calendar"
    case spending = "Spending"

    var id: Self { self }
}

struct BudgetScreen: View {
    @Environment(AppModel.self) private var model
    @State private var page = BudgetPage.overview
    @State private var newSource: IncomeSource?
    @State private var newExpense: Expense?
    @State private var newSpending: SpendEntry?
    @State private var namePrompt: NamePrompt?
    @State private var promptText = ""

    private enum NamePrompt: Identifiable {
        case category, incomeType
        var id: Self { self }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Page", selection: $page) {
                    ForEach(BudgetPage.allCases) { page in
                        Text(page.rawValue).tag(page)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .accessibilityIdentifier("budget.page")

                switch page {
                case .overview: OverviewPage()
                case .income: IncomePage()
                case .expenses: ExpensesPage()
                case .calendar: BillsCalendarPage()
                case .spending: SpendingPage()
                }
            }
            .background(Color.screenBackground)
            .navigationTitle("Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { addButton }
            }
            .sheet(item: $newSource) { IncomeEditor(source: $0) }
            .sheet(item: $newExpense) { ExpenseEditor(expense: $0) }
            .sheet(item: $newSpending) { SpendEditor(entry: $0, isNew: true) }
            .alert(
                namePrompt == .category ? "New category" : "New income type",
                isPresented: Binding(
                    get: { namePrompt != nil },
                    set: { if !$0 { namePrompt = nil } })
            ) {
                TextField("Name", text: $promptText)
                Button("Cancel", role: .cancel) {}
                Button("Add", action: addNamed)
            }
        }
    }

    @ViewBuilder
    private var addButton: some View {
        switch page {
        case .income:
            Menu("Add", systemImage: "plus") {
                Button("Income source") {
                    let type = model.tracker.value.incomeTypes.first ?? "Other"
                    newSource = IncomeSource(id: 0, name: "", incomeType: type)
                }
                Button("Income type") { ask(.incomeType) }
            }
            .accessibilityIdentifier("budget.add")
        case .expenses:
            Menu("Add", systemImage: "plus") {
                Button("Expense") {
                    let category = model.tracker.value.categories.first ?? TrackerConstants.uncategorized
                    newExpense = Expense(id: 0, name: "", cat: category, cost: 0)
                }
                Button("Category") { ask(.category) }
            }
            .accessibilityIdentifier("budget.add")
        case .spending:
            Button("Add", systemImage: "plus") {
                newSpending = SpendEntry(date: AppClock.now, amount: 0, merchant: "")
            }
            .accessibilityIdentifier("budget.add")
        case .overview, .calendar:
            EmptyView()
        }
    }

    private func ask(_ prompt: NamePrompt) {
        promptText = ""
        namePrompt = prompt
    }

    private func addNamed() {
        let name = promptText.trimmingCharacters(in: .whitespaces)
        switch namePrompt {
        case .category: model.tracker.update { $0.addCategory(name) }
        case .incomeType: model.tracker.update { $0.addIncomeType(name) }
        case nil: break
        }
    }
}
