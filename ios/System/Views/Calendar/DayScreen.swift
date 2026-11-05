import SwiftUI
import SystemCore

/// One day at a time, with this week's dates above it, like Apple's Calendar.
struct DayScreen: View {
    @Environment(AppModel.self) private var model
    @Binding var selected: CivilDate
    let onOpen: (BlockRef) -> Void
    let onAdd: (CivilDate, Int) -> Void
    @State private var page: Int?
    @State private var anchor = AppModel.shared.today

    var body: some View {
        VStack(spacing: 0) {
            WeekStrip(selected: $selected)
            Divider()
            TimelinePager(page: $page, showsNow: selected == model.today) { offset in
                DayColumn(date: anchor.adding(days: offset), onOpen: onOpen, onAdd: onAdd)
            }
        }
        .onAppear {
            page = anchor.days(to: selected)
        }
        .onChange(of: page) { _, page in
            if let page { selected = anchor.adding(days: page) }
        }
        .onChange(of: selected) { _, date in
            let target = anchor.days(to: date)
            if target != page {
                withAnimation(.easeInOut(duration: 0.25)) { page = target }
            }
        }
    }
}

struct WeekStrip: View {
    @Environment(AppModel.self) private var model
    @Binding var selected: CivilDate

    var body: some View {
        let start = selected.startOfWeek
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { index in
                let date = start.adding(days: index)
                Button {
                    selected = date
                } label: {
                    VStack(spacing: 3) {
                        Text(WeekdayHeader.letters[index])
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                        DayNumber(
                            date: date,
                            isToday: date == model.today,
                            isSelected: date == selected)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("strip.\(date.key)")
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
        .gesture(
            DragGesture(minimumDistance: 24).onEnded { value in
                guard abs(value.translation.width) > 40 else { return }
                selected = selected.adding(days: value.translation.width < 0 ? 7 : -7)
            })
    }
}

/// A date in a circle: red for today, dark for the selected day.
struct DayNumber: View {
    let date: CivilDate
    let isToday: Bool
    let isSelected: Bool

    var body: some View {
        Text("\(date.day)")
            .font(.system(size: 16, weight: isSelected || isToday ? .semibold : .regular))
            .monospacedDigit()
            .foregroundStyle(foreground)
            .frame(width: 32, height: 32)
            .background(Circle().fill(background))
    }

    private var foreground: Color {
        if isSelected { return isToday ? .white : Color(.systemBackground) }
        return isToday ? .red : .primary
    }

    private var background: Color {
        guard isSelected else { return .clear }
        return isToday ? .red : .primary
    }
}

struct WeekdayHeader: View {
    static let letters = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { index in
                Text(Self.letters[index])
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 4)
    }
}
