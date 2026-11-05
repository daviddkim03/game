import SwiftUI
import SystemCore

/// Paydays and bills by month. Tapping a date lists what lands on it.
struct BillsCalendarPage: View {
    @Environment(AppModel.self) private var model
    @State private var month = AppModel.shared.today.firstOfMonth
    @State private var selectedDay = AppModel.shared.today.day
    @State private var showPaydays = true
    @State private var showBills = true

    var body: some View {
        let data = model.tracker.value
        let built = buildCalendarMonth(
            data, year: month.year, month: month.month, showPaydays: showPaydays, showBills: showBills)
        ScrollView {
            VStack(spacing: 12) {
                Card {
                    MonthSwitcher(month: $month)
                    HStack(spacing: 8) {
                        FilterChip(
                            title: "Paydays", color: Color(hex: TrackerConstants.paydayColor), isOn: $showPaydays)
                        FilterChip(title: "Bills", color: .red, isOn: $showBills)
                        Spacer()
                    }
                    grid(built)
                }
                dayDetail(built)
                billsList(data)
            }
            .padding(12)
        }
        .refreshable { await model.refreshAll() }
        .onChange(of: month) { _, month in
            selectedDay = min(selectedDay, month.daysInMonth)
        }
    }

    private func grid(_ built: CalendarMonth) -> some View {
        let today = model.today
        var cells: [Int?] = Array(repeating: nil, count: built.firstWeekday)
        cells += (1...built.daysInMonth).map { Optional($0) }
        while cells.count % 7 != 0 { cells.append(nil) }
        let rows = stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<($0 + 7)]) }

        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"].indices, id: \.self) { index in
                    Text(["S", "M", "T", "W", "T", "F", "S"][index])
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 4)
            ForEach(rows.indices, id: \.self) { rowIndex in
                Divider()
                HStack(alignment: .top, spacing: 0) {
                    ForEach(0..<7, id: \.self) { index in
                        if let day = rows[rowIndex][index] {
                            let date = CivilDate(year: month.year, month: month.month, day: day)
                            BillDay(
                                day: day,
                                pills: built.pills[day] ?? [],
                                isToday: date == today,
                                isSelected: day == selectedDay
                            )
                            .onTapGesture { selectedDay = day }
                            .accessibilityIdentifier("bills.\(date.key)")
                            .accessibilityAddTraits(.isButton)
                        } else {
                            Color.clear.frame(maxWidth: .infinity, minHeight: BillDay.height)
                        }
                    }
                }
            }
        }
    }

    private func dayDetail(_ built: CalendarMonth) -> some View {
        let pills = built.pills[selectedDay] ?? []
        let date = CivilDate(year: month.year, month: month.month, day: selectedDay)
        return Card {
            HStack {
                Text(date.formatted("EEEE, MMM d"))
                    .font(.headline)
                Spacer()
                let net = built.runningNet[min(selectedDay, built.daysInMonth)]
                Text("\(net >= 0 ? "+" : "")\(formatUSD(net))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(net >= 0 ? Color.positive : .red)
                    .accessibilityLabel("Running net \(formatUSD(net))")
            }
            if pills.isEmpty {
                Text("Nothing due or paid")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(pills) { pill in
                HStack(spacing: 8) {
                    Image(systemName: pill.kind == .pay ? "arrow.up" : "arrow.down")
                        .font(.caption.bold())
                        .foregroundStyle(Color(hex: pill.color))
                    VStack(alignment: .leading, spacing: 0) {
                        Text(pill.label)
                            .font(.subheadline.weight(.medium))
                        if let moved = pill.shiftLabel {
                            Text("Moved from \(moved)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text(formatUSD(pill.amount))
                        .font(.subheadline.weight(.medium))
                }
            }
        }
    }

    private func billsList(_ data: TrackerData) -> some View {
        let bills = data.expenses
            .filter { $0.hasDueDate && $0.cat != TrackerConstants.uncategorized }
            .sorted { $0.dueSortKey < $1.dueSortKey }
        return Card {
            Text("Bills with due dates")
                .font(.headline)
            ForEach(bills) { bill in
                HStack {
                    Circle()
                        .fill(Color(hex: data.color(forCategory: bill.cat)))
                        .frame(width: 9, height: 9)
                    Text(bill.name)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text(bill.dueLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(formatUSD(bill.monthlyCost))
                        .font(.subheadline.weight(.medium))
                        .monospacedDigit()
                        .frame(minWidth: 56, alignment: .trailing)
                }
            }
        }
    }
}

private struct FilterChip: View {
    let title: String
    let color: Color
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(isOn ? color : Color(.systemGray3))
                    .frame(width: 9, height: 9)
                Text(title)
                    .font(.footnote.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.tertiarySystemFill), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct BillDay: View {
    static let height: CGFloat = 64

    let day: Int
    let pills: [CalendarPill]
    let isToday: Bool
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text("\(day)")
                .font(.system(size: 12, weight: isToday ? .bold : .regular))
                .monospacedDigit()
                .foregroundStyle(isToday ? .white : .primary)
                .frame(width: 21, height: 21)
                .background(Circle().fill(isToday ? Color.red : .clear))
            ForEach(pills.prefix(2)) { pill in
                Text(pill.label)
                    .font(.system(size: 8.5, weight: .medium))
                    .lineLimit(1)
                    .padding(.horizontal, 2)
                    .frame(maxWidth: .infinity, minHeight: 12, alignment: .leading)
                    .background(Color(hex: pill.color).opacity(0.28), in: RoundedRectangle(cornerRadius: 3))
            }
            if pills.count > 2 {
                Text("+\(pills.count - 2)")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 1)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, minHeight: Self.height, alignment: .top)
        .background(isSelected ? Color(.tertiarySystemFill) : .clear, in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
    }
}
