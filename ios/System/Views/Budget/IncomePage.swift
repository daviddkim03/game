import SwiftUI
import SystemCore

struct IncomePage: View {
    @Environment(AppModel.self) private var model
    @State private var editing: IncomeSource?

    var body: some View {
        let data = model.tracker.value
        List {
            Section {
                let summary = summarize(data)
                LabeledContent("Gross", value: formatUSD(summary.gross))
                LabeledContent("Take-home", value: formatUSD(summary.earn))
            }
            ForEach(data.incomeTypes, id: \.self) { type in
                let sources = data.income.filter { $0.incomeType == type }
                if !sources.isEmpty {
                    Section {
                        ForEach(sources) { source in
                            Button {
                                editing = source
                            } label: {
                                row(source, taxRate: data.taxRate)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("income.\(source.name)")
                        }
                        .onDelete { offsets in
                            let ids = offsets.map { sources[$0].id }
                            model.tracker.update { data in
                                for id in ids { data.deleteSource(id) }
                            }
                        }
                    } header: {
                        header(type, sources: sources, taxRate: data.taxRate)
                    }
                }
            }
        }
        .refreshable { await model.refreshAll() }
        .sheet(item: $editing) { IncomeEditor(source: $0) }
    }

    private func header(_ type: String, sources: [IncomeSource], taxRate: Double) -> some View {
        let gross = sources.reduce(0) { $0 + $1.monthlyGross }
        let net = sources.reduce(0) { $0 + $1.monthlyNet(taxRate: taxRate) }
        return HStack {
            Text(type)
            Spacer()
            Text("\(formatUSD(gross)) · \(formatUSD(net)) take-home")
                .monospacedDigit()
        }
    }

    private func row(_ source: IncomeSource, taxRate: Double) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(source.name.isEmpty ? "Untitled" : source.name)
                    .fontWeight(.medium)
                Text(details(source))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatUSD(source.monthlyGross))
                    .fontWeight(.medium)
                    .accessibilityIdentifier("income.amount.\(source.name)")
                Text("\(formatUSD(source.monthlyNet(taxRate: taxRate))) net")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }

    private func details(_ source: IncomeSource) -> String {
        let pay = source.isHourly ? "Hourly" : "Salary"
        let tax = source.isTaxed ? "Taxed" : "Untaxed"
        return "\(pay) · \(tax) · \(source.paydayLabel)"
    }
}

struct IncomeEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var draft: IncomeSource
    @State private var isConfirmingDelete = false

    init(source: IncomeSource) {
        _draft = State(initialValue: source)
    }

    private var isNew: Bool { draft.id == 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $draft.name)
                        .accessibilityIdentifier("income.name")
                    Picker("Type", selection: $draft.incomeType) {
                        ForEach(model.tracker.value.incomeTypes, id: \.self) { Text($0).tag($0) }
                    }
                    Toggle("Taxed", isOn: $draft.isTaxed)
                }
                Section {
                    Picker("Pay", selection: $draft.isHourly) {
                        Text("Salary").tag(false)
                        Text("Hourly").tag(true)
                    }
                    .pickerStyle(.segmented)
                    if draft.isHourly {
                        NumberField(title: "Hourly rate", value: $draft.rate)
                        NumberField(title: "Hours per week", value: $draft.hrsPerWeek)
                    } else {
                        NumberField(title: "Monthly salary", value: $draft.monthly)
                            .accessibilityIdentifier("income.monthly")
                        NumberField(title: "Annual bonus", value: $draft.rate)
                    }
                }
                Section("Payday") {
                    Picker("Repeats", selection: $draft.paydayIsWeekdays) {
                        Text("Dates").tag(false)
                        Text("Weekdays").tag(true)
                    }
                    .pickerStyle(.segmented)
                    if draft.paydayIsWeekdays {
                        WeekdayPicker(selection: $draft.paydayWeekdays)
                    } else {
                        MonthDayPicker(selection: $draft.paydayDates)
                    }
                    Toggle("Show on calendar", isOn: $draft.showOnCal)
                }
                if !isNew {
                    Section {
                        Button("Delete", role: .destructive) { isConfirmingDelete = true }
                    }
                }
            }
            .navigationTitle(isNew ? "New source" : "Edit source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let source = draft
                        model.tracker.update { $0.save(source) }
                        dismiss()
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("income.save")
                }
            }
            .confirmationDialog("Delete \(draft.name)?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    let id = draft.id
                    model.tracker.update { $0.deleteSource(id) }
                    dismiss()
                }
            }
        }
    }
}

/// Picks any of the seven weekdays (0 = Sunday, matching the website).
struct WeekdayPicker: View {
    @Binding var selection: [Int]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { day in
                let isOn = selection.contains(day)
                Button {
                    if isOn {
                        selection.removeAll { $0 == day }
                    } else {
                        selection.append(day)
                        selection.sort()
                    }
                } label: {
                    Text(TrackerConstants.shortDays[day].prefix(2))
                        .font(.footnote.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(
                            isOn ? Color.accentColor : Color(.tertiarySystemFill),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .foregroundStyle(isOn ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Picks any days of the month.
struct MonthDayPicker: View {
    @Binding var selection: [Int]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
            ForEach(1...31, id: \.self) { day in
                let isOn = selection.contains(day)
                Button {
                    if isOn {
                        selection.removeAll { $0 == day }
                    } else {
                        selection.append(day)
                        selection.sort()
                    }
                } label: {
                    Text("\(day)")
                        .font(.footnote.weight(.medium))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(
                            isOn ? Color.accentColor : Color(.tertiarySystemFill),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .foregroundStyle(isOn ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
