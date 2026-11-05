import SwiftUI
import SystemCore

/// A new or existing weekly block being edited.
struct BlockDraft: Identifiable {
    let id = UUID()
    var block: Block
}

extension AppModel {
    /// A new block on `date` at `slot`, in the last color used.
    func newBlockDraft(on date: CivilDate, slot: Int = 6) -> BlockDraft {
        let start = max(0, min(ScheduleGrid.slotCount - 2, slot))
        return BlockDraft(
            block: Block(
                id: 0, day: date.mondayIndex, start: start, end: start + 2, label: "",
                color: schedule.value.selColor))
    }
}

/// What a block is and everything that can be done to it.
struct BlockSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let ref: BlockRef
    @State private var editing: BlockDraft?
    @State private var isConfirmingDelete = false
    @State private var session: SessionDraft?

    var body: some View {
        let plan = model.plan(for: ref.date)
        let active = plan.blocks.first { $0.id == ref.blockId }
        let skipped = plan.skipped.first { $0.id == ref.blockId }
        let isToday = ref.date == model.today

        NavigationStack {
            List {
                if let block = active ?? skipped {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(Color(hex: block.color))
                                    .frame(width: 12, height: 12)
                                Text(block.label)
                                    .font(.title3.bold())
                                    .accessibilityIdentifier("block.title")
                            }
                            Text("\(ref.date.formatted("EEE, MMM d")) · \(block.timeLabel)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("block.time")
                        }
                    }

                    Section {
                        if let active, isToday {
                            Button("+15 min", systemImage: "plus") {
                                model.addFifteen(to: active.id, on: ref.date)
                            }
                            .accessibilityIdentifier("block.extend")
                            if active.extraMinutes > 0 {
                                Button("Undo +15 min", systemImage: "arrow.uturn.backward") {
                                    model.undoFifteen(from: active.id, on: ref.date)
                                }
                                .accessibilityIdentifier("block.undoExtend")
                            }
                        }
                        if skipped != nil {
                            Button("Restore", systemImage: "arrow.uturn.backward") {
                                model.restore(ref.blockId, on: ref.date)
                            }
                            .accessibilityIdentifier("block.restore")
                        } else {
                            Button(
                                isToday ? "Skip today" : "Skip this day",
                                systemImage: "forward.end"
                            ) {
                                model.skip(ref.blockId, on: ref.date)
                                dismiss()
                            }
                            .accessibilityIdentifier("block.skip")
                        }
                        if let active, model.report.value.isTutoring(active.label) {
                            Button("Log session", systemImage: "square.and.pencil") {
                                session = model.sessionDraft(for: active, on: ref.date)
                            }
                            .accessibilityIdentifier("block.log")
                        }
                    }

                    Section {
                        Button("Edit every \(ref.date.formatted("EEEE"))", systemImage: "pencil") {
                            if let weekly = model.schedule.value.blocks.first(where: { $0.id == ref.blockId }) {
                                editing = BlockDraft(block: weekly)
                            }
                        }
                        .accessibilityIdentifier("block.edit")
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            isConfirmingDelete = true
                        }
                        .accessibilityIdentifier("block.delete")
                    }
                } else {
                    Text("This block is gone for the day.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Delete this block from every week?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    model.schedule.update { $0.delete(ref.blockId) }
                    dismiss()
                }
            }
            .sheet(item: $editing) { draft in
                BlockEditor(block: draft.block)
            }
            .sheet(item: $session) { draft in
                SessionEditor(draft: draft)
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Adds a block or changes a weekly one. Whatever it covers gets trimmed.
struct BlockEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Block
    private let isNew: Bool

    init(block: Block) {
        _draft = State(initialValue: block)
        isNew = block.id == 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Label", text: $draft.label)
                        .accessibilityIdentifier("editor.label")
                }
                Section {
                    Picker("Day", selection: $draft.day) {
                        ForEach(ScheduleGrid.dayNames.indices, id: \.self) { index in
                            Text(ScheduleGrid.dayNames[index]).tag(index)
                        }
                    }
                    Picker("Starts", selection: $draft.start) {
                        ForEach(0..<ScheduleGrid.slotCount, id: \.self) { slot in
                            Text(ScheduleGrid.slotLabel(slot)).tag(slot)
                        }
                    }
                    .accessibilityIdentifier("editor.start")
                    Picker("Ends", selection: $draft.end) {
                        ForEach((draft.start + 1)...ScheduleGrid.slotCount, id: \.self) { slot in
                            Text(ScheduleGrid.slotLabel(slot)).tag(slot)
                        }
                    }
                    .accessibilityIdentifier("editor.end")
                }
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(ScheduleGrid.colors, id: \.value) { color in
                            Button {
                                draft.color = color.value
                            } label: {
                                Circle()
                                    .fill(Color(hex: color.value))
                                    .frame(width: 34, height: 34)
                                    .overlay {
                                        if draft.color.caseInsensitiveCompare(color.value) == .orderedSame {
                                            Image(systemName: "checkmark")
                                                .font(.footnote.bold())
                                                .foregroundStyle(Color.readable(on: color.value))
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(color.name)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(isNew ? "New block" : "Edit block")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: draft.start) { _, start in
                if draft.end <= start { draft.end = min(start + 2, ScheduleGrid.slotCount) }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .accessibilityIdentifier("editor.save")
                }
            }
        }
    }

    private func save() {
        var block = draft
        let label = block.label.trimmingCharacters(in: .whitespaces)
        block.label = label.isEmpty ? "Block" : label
        model.schedule.update { $0.save(block) }
        dismiss()
    }
}
