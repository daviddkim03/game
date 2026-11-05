import SwiftUI
import SystemCore

/// Seven days side by side.
struct WeekScreen: View {
    @Environment(AppModel.self) private var model
    @Binding var selected: CivilDate
    let onOpen: (BlockRef) -> Void
    let onAdd: (CivilDate, Int) -> Void
    let onPickDay: (CivilDate) -> Void
    @State private var page: Int?
    @State private var anchor = AppModel.shared.today.startOfWeek

    private var weekStart: CivilDate {
        anchor.adding(days: (page ?? 0) * 7)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            TimelinePager(page: $page, showsNow: (0..<7).contains(weekStart.days(to: model.today))) { offset in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { index in
                        DayColumn(
                            date: anchor.adding(days: offset * 7 + index),
                            isCompact: true,
                            onOpen: onOpen,
                            onAdd: onAdd)
                        if index < 6 {
                            Rectangle()
                                .fill(Color(.separator))
                                .frame(width: 0.5)
                        }
                    }
                }
            }
        }
        .onAppear {
            page = anchor.days(to: selected.startOfWeek) / 7
        }
        .onChange(of: page) { _, page in
            guard let page else { return }
            let date = anchor.adding(days: page * 7 + selected.mondayIndex)
            if date != selected { selected = date }
        }
        .onChange(of: selected) { _, date in
            let target = anchor.days(to: date.startOfWeek) / 7
            if target != page {
                withAnimation(.easeInOut(duration: 0.25)) { page = target }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: Timeline.gutter, height: 1)
            ForEach(0..<7, id: \.self) { index in
                let date = weekStart.adding(days: index)
                Button {
                    onPickDay(date)
                } label: {
                    VStack(spacing: 2) {
                        Text(WeekdayHeader.letters[index])
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                        DayNumber(date: date, isToday: date == model.today, isSelected: date == model.today)
                            .scaleEffect(0.86)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("week.\(date.key)")
            }
        }
        .padding(.bottom, 2)
    }
}
