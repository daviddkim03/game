import SwiftUI
import SystemCore

/// Twelve small months per year. Tapping one opens it.
struct YearScreen: View {
    @Environment(AppModel.self) private var model
    @Binding var selected: CivilDate
    let onPickMonth: (CivilDate) -> Void

    private var years: ClosedRange<Int> {
        let year = model.today.year
        return (year - 5)...(year + 5)
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 18, alignment: .top), count: 3)

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(years, id: \.self) { year in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(String(year))
                                .font(.largeTitle.bold())
                                .foregroundStyle(year == model.today.year ? .red : .primary)
                            LazyVGrid(columns: columns, spacing: 22) {
                                ForEach(1...12, id: \.self) { month in
                                    let first = CivilDate(year: year, month: month, day: 1)
                                    Button {
                                        onPickMonth(first)
                                    } label: {
                                        MiniMonth(month: first, today: model.today)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("year.\(first.key)")
                                }
                            }
                        }
                        .id(year)
                    }
                }
                .padding(16)
            }
            .onAppear {
                proxy.scrollTo(selected.year, anchor: .top)
            }
        }
    }
}

private struct MiniMonth: View {
    let month: CivilDate
    let today: CivilDate

    var body: some View {
        let cells: [Int?] =
            Array(repeating: nil, count: month.mondayIndex)
            + (1...month.daysInMonth).map { Optional($0) }
        VStack(alignment: .leading, spacing: 4) {
            Text(month.formatted("MMM"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(month == today.firstOfMonth ? .red : .primary)
            let rows = stride(from: 0, to: cells.count, by: 7).map {
                Array(cells[$0..<min($0 + 7, cells.count)])
            }
            VStack(alignment: .leading, spacing: 1) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { index in
                            cell(index < row.count ? row[index] : nil)
                        }
                    }
                }
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func cell(_ day: Int?) -> some View {
        let isToday = day.map { month.adding(days: $0 - 1) == today } ?? false
        Text(day.map(String.init) ?? " ")
            .font(.system(size: 7.5, weight: isToday ? .bold : .regular))
            .monospacedDigit()
            .foregroundStyle(isToday ? .white : .primary)
            .frame(maxWidth: .infinity, minHeight: 10)
            .background(Circle().fill(isToday ? Color.red : .clear).frame(width: 12, height: 12))
    }
}
