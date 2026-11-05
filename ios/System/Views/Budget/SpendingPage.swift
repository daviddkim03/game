import SwiftUI
import SystemCore

/// Purchases logged by hand or from Apple Pay, against the month's plan.
struct SpendingPage: View {
    @Environment(AppModel.self) private var model
    @State private var month = AppModel.shared.today.firstOfMonth
    @State private var editing: SpendEntry?

    var body: some View {
        let store = model.spending(for: month)
        let spending = store.value
        let data = model.tracker.value
        let plan = FlexiblePlan(data)
        let days = Dictionary(grouping: spending.sorted) { CivilDate($0.date) }

        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    MonthSwitcher(month: $month)
                        .buttonStyle(.borderless)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(formatUSD(spending.total, cents: true))
                            .font(.title.bold())
                            .accessibilityIdentifier("spending.total")
                        Text("of \(formatUSD(plan.total))")
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: min(spending.total, max(plan.total, 1)), total: max(plan.total, 1))
                        .tint(spending.total > plan.total ? .red : .positive)
                }
                .padding(.vertical, 4)
            }

            let categories = data.categories.filter {
                (plan.byCategory[$0] ?? 0) > 0 || spending.total(forCategory: $0) > 0
            }
            if !categories.isEmpty {
                Section("By category") {
                    ForEach(categories, id: \.self) { category in
                        CategoryRow(
                            name: category,
                            color: data.color(forCategory: category),
                            spent: spending.total(forCategory: category),
                            planned: plan.byCategory[category] ?? 0)
                    }
                }
            }

            ForEach(days.keys.sorted(by: >)) { day in
                Section(day.formatted("EEEE, MMM d")) {
                    ForEach(days[day] ?? []) { entry in
                        row(entry)
                    }
                    .onDelete { offsets in
                        let entries = days[day] ?? []
                        for index in offsets { model.deleteSpending(entries[index]) }
                    }
                }
            }
        }
        .overlay {
            if spending.entries.isEmpty, store.isLoaded {
                Text("Nothing logged this month")
                    .foregroundStyle(.secondary)
                    .padding(.top, 240)
            }
        }
        .refreshable { await store.refresh() }
        .sheet(item: $editing) { SpendEditor(entry: $0, isNew: false) }
    }

    private func row(_ entry: SpendEntry) -> some View {
        Button {
            editing = entry
        } label: {
            HStack(spacing: 10) {
                if entry.source == .applePay {
                    Image(systemName: "applelogo")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Apple Pay")
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.merchant.isEmpty ? "Purchase" : entry.merchant)
                        .fontWeight(.medium)
                    Text(entry.category ?? "Pick a category")
                        .font(.footnote)
                        .foregroundStyle(entry.category == nil ? Color.orange : .secondary)
                }
                Spacer()
                Text(formatUSD(entry.amount, cents: true))
                    .fontWeight(.medium)
                    .monospacedDigit()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("spend.\(entry.merchant)")
    }
}

private struct CategoryRow: View {
    let name: String
    let color: String
    let spent: Double
    let planned: Double

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(name)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(formatUSD(spent)) of \(formatUSD(planned))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            ProgressView(value: min(spent, max(planned, 1)), total: max(planned, 1))
                .tint(spent > planned ? .red : Color(hex: color))
        }
    }
}

struct SpendEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var draft: SpendEntry
    @State private var amount: Double?
    @FocusState private var isAmountFocused: Bool
    private let isNew: Bool
    private let original: SpendEntry

    init(entry: SpendEntry, isNew: Bool) {
        _draft = State(initialValue: entry)
        _amount = State(initialValue: isNew ? nil : entry.amount)
        self.isNew = isNew
        original = entry
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 2) {
                        Text("$")
                            .font(.title.bold())
                            .foregroundStyle(.secondary)
                        DecimalField("0.00", value: $amount)
                            .font(.title.bold())
                            .focused($isAmountFocused)
                            .accessibilityIdentifier("spend.amount")
                    }
                    TextField("Merchant", text: $draft.merchant)
                        .accessibilityIdentifier("spend.merchant")
                }
                Section {
                    Picker("Category", selection: $draft.category) {
                        Text("None").tag(String?.none)
                        ForEach(model.tracker.value.categories, id: \.self) { category in
                            Text(category).tag(String?.some(category))
                        }
                    }
                    .accessibilityIdentifier("spend.category")
                    DatePicker("Date", selection: $draft.date, displayedComponents: [.date, .hourAndMinute])
                }
                if !isNew {
                    Section {
                        Button("Delete", role: .destructive) {
                            model.deleteSpending(draft)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "New purchase" : "Edit purchase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled((amount ?? 0) <= 0)
                        .accessibilityIdentifier("spend.save")
                }
            }
            .onAppear {
                if isNew { isAmountFocused = true }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        var entry = draft
        entry.amount = amount ?? 0
        entry.merchant = entry.merchant.trimmingCharacters(in: .whitespaces)
        if isNew, entry.category == nil {
            entry.category = model.phone.value.merchantCategories[entry.merchant.lowercased()]
        }
        model.saveSpending(entry, replacing: isNew ? nil : original)
        dismiss()
    }
}
