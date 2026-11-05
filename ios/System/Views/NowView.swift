import SwiftUI
import SystemCore

/// What's happening right now, what's next, and the rest of today.
struct NowView: View {
    @Environment(AppModel.self) private var model
    @State private var selected: BlockRef?
    @State private var isShowingSettings = false
    @State private var session: SessionDraft?

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { _ in
                let now = AppClock.now
                let today = CivilDate(now)
                content(today: today, minute: CivilDate.minuteOfDay(now))
                    .navigationTitle(today.formatted("EEEE, MMM d"))
            }
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") {
                        isShowingSettings = true
                    }
                    .accessibilityIdentifier("now.settings")
                }
            }
            .sheet(item: $selected) { ref in
                BlockSheet(ref: ref)
            }
            .sheet(item: $session) { draft in
                SessionEditor(draft: draft)
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
        }
    }

    @ViewBuilder
    private func content(today: CivilDate, minute: Int) -> some View {
        let plan = model.plan(for: today)
        let state = plan.now(at: minute)
        List {
            Section {
                card(state: state, today: today)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            if !plan.blocks.isEmpty {
                Section {
                    ForEach(plan.blocks) { block in
                        row(block, state: state, today: today, minute: minute)
                    }
                } header: {
                    sectionHeader("Today")
                }
            }

            if !plan.skipped.isEmpty {
                Section {
                    ForEach(plan.skipped) { block in
                        skippedRow(block, today: today)
                    }
                } header: {
                    sectionHeader("Skipped")
                }
            }
        }
        .listStyle(.plain)
        .refreshable { await model.refreshAll() }
        .overlay {
            if !model.schedule.isLoaded {
                ProgressView()
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func card(state: NowState, today: CivilDate) -> some View {
        if let current = state.current {
            CurrentCard(
                thing: current,
                state: state,
                canLogSession: model.report.value.isTutoring(current.label),
                onExtend: { model.addFifteen(to: current.lastBlockId, on: today) },
                onUndoExtend: { model.undoFifteen(from: current.lastBlockId, on: today) },
                onSkip: {
                    for block in current.blocks { model.skip(block.id, on: today) }
                },
                onLog: {
                    if let block = current.blocks.last {
                        session = model.sessionDraft(for: block, on: today)
                    }
                })
        } else {
            FreeCard(state: state)
        }
    }

    private func row(_ block: PlannedBlock, state: NowState, today: CivilDate, minute: Int) -> some View {
        let isCurrent = state.current?.blocks.contains { $0.id == block.id } == true
        return Button {
            selected = BlockRef(date: today, blockId: block.id)
        } label: {
            HStack(spacing: 12) {
                Capsule()
                    .fill(Color(hex: block.color))
                    .frame(width: 4, height: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(block.label)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(block.timeLabel)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isCurrent {
                    Text("Now")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                } else if block.extraMinutes > 0 {
                    Text("+\(block.extraMinutes) min")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .opacity(block.end <= minute ? 0.45 : 1)
        }
        .accessibilityIdentifier("today.\(block.label)")
        .swipeActions(edge: .trailing) {
            Button("Skip") {
                model.skip(block.id, on: today)
            }
            .tint(.orange)
        }
    }

    private func skippedRow(_ block: PlannedBlock, today: CivilDate) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(block.label)
                    .strikethrough()
                Text(block.timeLabel)
                    .font(.footnote)
            }
            .foregroundStyle(.secondary)
            Spacer()
            Button("Restore") {
                model.restore(block.id, on: today)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("skipped.restore.\(block.label)")
        }
    }
}

/// The running thing, big and in its own color.
private struct CurrentCard: View {
    let thing: Thing
    let state: NowState
    let canLogSession: Bool
    let onExtend: () -> Void
    let onUndoExtend: () -> Void
    let onSkip: () -> Void
    let onLog: () -> Void

    var body: some View {
        let foreground = Color.readable(on: thing.color)
        VStack(alignment: .leading, spacing: 0) {
            Text("Now")
                .font(.footnote.weight(.semibold))
                .opacity(0.8)
            Text(thing.label)
                .font(.system(size: 34, weight: .bold))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .accessibilityIdentifier("now.label")
            Text("Ends \(clockLabel(thing.end))")
                .font(.body.weight(.medium))
                .padding(.top, 2)
                .accessibilityIdentifier("now.ends")

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(durationLabel(minutes: state.minutesLeft ?? 0))
                    .font(.system(size: 28, weight: .semibold))
                    .monospacedDigit()
                Text("left")
                    .font(.body)
                    .opacity(0.85)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("now.left")
            .padding(.top, 18)

            ProgressBar(value: state.progress, color: foreground)
                .padding(.top, 8)

            if let next = state.next {
                Text("Next: \(next.label) at \(clockLabel(next.start))")
                    .font(.subheadline.weight(.medium))
                    .padding(.top, 12)
                    .accessibilityIdentifier("now.next")
            }

            HStack(spacing: 10) {
                CardButton(title: "+15 min", color: foreground, action: onExtend)
                    .accessibilityIdentifier("now.extend")
                CardButton(title: "Skip today", color: foreground, action: onSkip)
                    .accessibilityIdentifier("now.skip")
                if canLogSession {
                    CardButton(title: "Log", color: foreground, action: onLog)
                        .accessibilityIdentifier("now.log")
                }
            }
            .padding(.top, 16)

            if thing.extraMinutes > 0 {
                Button("Added \(thing.extraMinutes) min. Undo 15", action: onUndoExtend)
                    .font(.footnote.weight(.medium))
                    .buttonStyle(.plain)
                    .padding(.top, 10)
                    .accessibilityIdentifier("now.undoExtend")
            }
        }
        .foregroundStyle(foreground)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: thing.color), in: RoundedRectangle(cornerRadius: 24))
    }
}

private struct ProgressBar: View {
    let value: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.25))
                Capsule()
                    .fill(color)
                    .frame(width: proxy.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

private struct CardButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 42)
                .background(color.opacity(0.18), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Nothing is running.
private struct FreeCard: View {
    let state: NowState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Now")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Free")
                .font(.system(size: 34, weight: .bold))
                .accessibilityIdentifier("now.label")
            if let next = state.next {
                Text("Until \(clockLabel(next.start))")
                    .font(.body.weight(.medium))
                Text("Next: \(next.label) in \(durationLabel(minutes: next.start - state.minute))")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)
                    .accessibilityIdentifier("now.next")
            } else {
                Text("Nothing else today")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 24))
    }
}
