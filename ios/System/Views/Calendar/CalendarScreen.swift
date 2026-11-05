import SwiftUI
import SystemCore

enum CalendarMode: String, CaseIterable, Identifiable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case year = "Year"

    var id: Self { self }
}

/// The schedule by day, week, month, or year.
struct CalendarScreen: View {
    @Environment(AppModel.self) private var model
    @State private var mode = CalendarMode.day
    @State private var selected = AppModel.shared.today
    @State private var openBlock: BlockRef?
    @State private var newBlock: BlockDraft?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $mode) {
                    ForEach(CalendarMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .accessibilityIdentifier("calendar.mode")

                switch mode {
                case .day:
                    DayScreen(selected: $selected, onOpen: open, onAdd: add)
                case .week:
                    WeekScreen(selected: $selected, onOpen: open, onAdd: add, onPickDay: showDay)
                case .month:
                    MonthScreen(selected: $selected, onPickDay: showDay)
                case .year:
                    YearScreen(selected: $selected) { month in
                        selected = month
                        mode = .month
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Today") {
                        selected = model.today
                    }
                    .accessibilityIdentifier("calendar.today")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add", systemImage: "plus") {
                        newBlock = model.newBlockDraft(on: selected)
                    }
                    .accessibilityIdentifier("calendar.add")
                }
            }
            .sheet(item: $openBlock) { ref in
                BlockSheet(ref: ref)
            }
            .sheet(item: $newBlock) { draft in
                BlockEditor(block: draft.block)
            }
        }
        .tint(.red)
    }

    private var title: String {
        switch mode {
        case .day: selected.formatted("EEEE, MMMM d")
        case .week, .month: selected.formatted("MMMM yyyy")
        case .year: String(selected.year)
        }
    }

    private func open(_ ref: BlockRef) {
        openBlock = ref
    }

    private func add(_ date: CivilDate, _ slot: Int) {
        newBlock = model.newBlockDraft(on: date, slot: slot)
    }

    private func showDay(_ date: CivilDate) {
        selected = date
        mode = .day
    }
}
