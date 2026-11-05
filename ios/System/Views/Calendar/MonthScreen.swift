import SwiftUI
import SystemCore

/// Months in one continuous scroll. Tapping a date opens that day.
struct MonthScreen: View {
    @Environment(AppModel.self) private var model
    @Binding var selected: CivilDate
    let onPickDay: (CivilDate) -> Void
    @State private var visible: Int?
    @State private var anchor = AppModel.shared.today.firstOfMonth

    private var range: ClosedRange<Int> { -60...60 }

    var body: some View {
        VStack(spacing: 0) {
            WeekdayHeader()
            Divider()
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(range, id: \.self) { offset in
                        MonthGrid(month: anchor.adding(months: offset), onPickDay: onPickDay)
                            .id(offset)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollPosition(id: $visible, anchor: .top)
        }
        .onAppear {
            visible = monthOffset(selected)
        }
        .onChange(of: visible) { _, offset in
            guard let offset else { return }
            let month = anchor.adding(months: offset)
            if month != selected.firstOfMonth {
                selected = selected.adding(months: monthOffset(month) - monthOffset(selected))
            }
        }
        .onChange(of: selected) { _, date in
            let target = monthOffset(date)
            if visible != target {
                withAnimation(.easeInOut(duration: 0.25)) { visible = target }
            }
        }
    }

    private func monthOffset(_ date: CivilDate) -> Int {
        (date.year - anchor.year) * 12 + date.month - anchor.month
    }
}

private struct MonthGrid: View {
    @Environment(AppModel.self) private var model
    let month: CivilDate
    let onPickDay: (CivilDate) -> Void

    /// The month's days in rows of seven, with blanks around them.
    private var weeks: [[CivilDate?]] {
        var cells: [CivilDate?] = Array(repeating: nil, count: month.mondayIndex)
        cells += (0..<month.daysInMonth).map { month.adding(days: $0) }
        while cells.count % 7 != 0 { cells.append(nil) }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<($0 + 7)]) }
    }

    var body: some View {
        let today = model.today
        VStack(alignment: .leading, spacing: 0) {
            Text(month.formatted("MMMM"))
                .font(.title3.bold())
                .foregroundStyle(month == today.firstOfMonth ? .red : .primary)
                .padding(.horizontal, 12)
                .padding(.top, 14)
                .padding(.bottom, 8)
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                Divider()
                HStack(alignment: .top, spacing: 0) {
                    ForEach(0..<7, id: \.self) { index in
                        if let date = week[index] {
                            MonthDay(date: date, isToday: date == today)
                                .onTapGesture { onPickDay(date) }
                                .accessibilityIdentifier("month.\(date.key)")
                                .accessibilityAddTraits(.isButton)
                        } else {
                            Color.clear.frame(maxWidth: .infinity, minHeight: MonthDay.height)
                        }
                    }
                }
            }
        }
    }
}

private struct MonthDay: View {
    @Environment(AppModel.self) private var model
    static let height: CGFloat = 92
    static let visibleChips = 3

    let date: CivilDate
    let isToday: Bool

    var body: some View {
        let blocks = model.plan(for: date).things
        VStack(spacing: 2) {
            Text("\(date.day)")
                .font(.system(size: 13, weight: isToday ? .bold : .regular))
                .monospacedDigit()
                .foregroundStyle(isToday ? .white : date.mondayIndex >= 5 ? .secondary : .primary)
                .frame(width: 24, height: 24)
                .background(Circle().fill(isToday ? Color.red : .clear))
            ForEach(blocks.prefix(Self.visibleChips)) { thing in
                Text(thing.label)
                    .font(.system(size: 9, weight: .medium))
                    .lineLimit(1)
                    .padding(.horizontal, 3)
                    .frame(maxWidth: .infinity, minHeight: 13, alignment: .leading)
                    .background(Color(hex: thing.color).opacity(0.28), in: RoundedRectangle(cornerRadius: 3))
            }
            if blocks.count > Self.visibleChips {
                Text("+\(blocks.count - Self.visibleChips)")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 1.5)
        .padding(.top, 3)
        .frame(maxWidth: .infinity, minHeight: Self.height, alignment: .top)
        .contentShape(Rectangle())
    }
}
