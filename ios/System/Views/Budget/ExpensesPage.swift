import SwiftUI
import SystemCore

struct ExpensesPage: View {
    @Environment(AppModel.self) private var model
    @State private var editing: Expense?

    private var sections: [String] {
        let data = model.tracker.value
        let hasUncategorized = data.expenses.contains { $0.cat == TrackerConstants.uncategorized }
        return (hasUncategorized ? [TrackerConstants.uncategorized] : []) + data.categories
    }

    var body: some View {
        let data = model.tracker.value
        let summary = summarize(data)
        List {
            Section {
                LabeledContent("Total per month", value: formatUSD(summary.expenses))
                    .accessibilityIdentifier("expenses.total")
            }
            ForEach(sections, id: \.self) { category in
                let expenses = data.expenses.filter { $0.cat == category }
                Section {
                    ForEach(expenses) { expense in
                        row(expense)
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { expenses[$0].id }
                        model.tracker.update { data in
                            for id in ids { data.deleteExpense(id) }
                        }
                    }
                } header: {
                    HStack {
                        Circle()
                            .fill(Color(hex: data.color(forCategory: category)))
                            .frame(width: 9, height: 9)
                        Text(category)
                        Spacer()
                        Text(sectionTotal(category, summary: summary, take: summary.earn))
                            .monospacedDigit()
                    }
                }
            }
        }
        .refreshable { await model.refreshAll() }
        .sheet(item: $editing) { ExpenseEditor(expense: $0) }
    }

    private func sectionTotal(_ category: String, summary: TrackerSummary, take: Double) -> String {
        guard let total = summary.byCategory[category] else { return "" }
        let share = take > 0 ? Int((total / take * 100).rounded()) : 0
        return "\(formatUSD(total)) · \(share)%"
    }

    private func row(_ expense: Expense) -> some View {
        Button {
            editing = expense
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(expense.name.isEmpty ? "Untitled" : expense.name)
                        .fontWeight(.medium)
                    if expense.hasDueDate {
                        Text("Due \(expense.dueLabel)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let link = safeLink(expense.paymentLink) {
                    Link(destination: link) {
                        Image(systemName: "link")
                            .font(.footnote)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Open payment link for \(expense.name)")
                }
                Text(formatUSD(expense.monthlyCost))
                    .fontWeight(.medium)
                    .monospacedDigit()
                    .accessibilityIdentifier("expense.amount.\(expense.name)")
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("expense.\(expense.name)")
    }
}

struct ExpenseEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Expense
    @State private var cost: Double?
    @State private var isConfirmingDelete = false

    init(expense: Expense) {
        _draft = State(initialValue: expense)
        _cost = State(initialValue: expense.id == 0 ? nil : expense.cost)
    }

    private var isNew: Bool { draft.id == 0 }

    private var categories: [String] {
        let list = model.tracker.value.categories
        return list.contains(draft.cat) ? list : [draft.cat] + list
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $draft.name)
                        .accessibilityIdentifier("expense.name")
                    NumberField(title: draft.dueIsWeekdays ? "Cost each time" : "Cost per month", value: $cost)
                        .accessibilityIdentifier("expense.cost")
                    Picker("Category", selection: $draft.cat) {
                        ForEach(categories, id: \.self) { Text($0).tag($0) }
                    }
                }
                Section("Due") {
                    Picker("Repeats", selection: $draft.dueIsWeekdays) {
                        Text("Date").tag(false)
                        Text("Weekdays").tag(true)
                    }
                    .pickerStyle(.segmented)
                    if draft.dueIsWeekdays {
                        WeekdayPicker(selection: $draft.dueWeekdays)
                    } else {
                        Picker("Day of month", selection: $draft.due) {
                            Text("None").tag(Int?.none)
                            ForEach(1...31, id: \.self) { day in
                                Text("\(day)\(ordinalSuffix(day))").tag(Int?.some(day))
                            }
                        }
                    }
                    Toggle("Show on calendar", isOn: $draft.showOnCal)
                }
                Section("Payment link") {
                    TextField("pay.example.com", text: paymentLink)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                if !isNew {
                    Section {
                        Button("Delete", role: .destructive) { isConfirmingDelete = true }
                    }
                }
            }
            .navigationTitle(isNew ? "New expense" : "Edit expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityIdentifier("expense.save")
                }
            }
            .confirmationDialog("Delete \(draft.name)?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    let id = draft.id
                    model.tracker.update { $0.deleteExpense(id) }
                    dismiss()
                }
            }
        }
    }

    private var paymentLink: Binding<String> {
        Binding(
            get: { draft.paymentLink ?? "" },
            set: { draft.paymentLink = $0.isEmpty ? nil : $0 })
    }

    private func save() {
        var expense = draft
        expense.cost = cost ?? 0
        model.tracker.update { $0.save(expense) }
        dismiss()
    }
}
