import SwiftUI
import SystemCore

/// The payment report: students, sessions, and what they add up to.
struct TutoringScreen: View {
    @Environment(AppModel.self) private var model
    @State private var session: SessionDraft?
    @State private var editingSession: EditingSession?
    @State private var isAddingStudent = false
    @State private var studentName = ""
    @State private var studentSubject = ""
    @State private var isEditingReport = false

    private struct EditingSession: Identifiable {
        let studentId: Int
        let session: TutoringSession
        var id: Int { session.id }
    }

    var body: some View {
        @Bindable var model = model
        let report = model.report.value
        NavigationStack {
            List {
                Section {
                    LabeledContent("Period", value: periodLabel(report))
                    LabeledContent("Hours", value: formatNumber(report.hours))
                    LabeledContent("Total") {
                        Text(formatUSD(report.total))
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .accessibilityIdentifier("tutoring.total")
                    }
                }

                ForEach(report.students) { student in
                    Section {
                        ForEach(sorted(student)) { item in
                            Button {
                                editingSession = EditingSession(studentId: student.id, session: item)
                            } label: {
                                row(item, rate: report.rate)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("session.\(student.name).\(item.date)")
                        }
                        .onDelete { offsets in
                            let items = sorted(student)
                            let ids = offsets.map { items[$0].id }
                            model.report.update { report in
                                for id in ids { report.deleteSession(id, studentId: student.id) }
                            }
                        }
                        if student.sessions.isEmpty {
                            Text("No sessions yet")
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        HStack {
                            Text("\(student.name) · \(student.subject)")
                            Spacer()
                            Text("\(formatNumber(student.hours)) hrs · \(formatUSD(report.total(for: student)))")
                                .monospacedDigit()
                        }
                    }
                }
            }
            .refreshable { await model.refreshAll() }
            .overlay {
                if model.report.isLoaded, report.students.isEmpty {
                    Text("No students yet")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Tutoring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Edit") { isEditingReport = true }
                        .accessibilityIdentifier("tutoring.edit")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Add", systemImage: "plus") {
                        Button("Session") {
                            session = SessionDraft(
                                studentId: report.students.first?.id, date: model.today, startMinute: nil, hours: 1)
                        }
                        .disabled(report.students.isEmpty)
                        Button("Student") {
                            studentName = ""
                            studentSubject = ""
                            isAddingStudent = true
                        }
                    }
                    .accessibilityIdentifier("tutoring.add")
                }
            }
            .sheet(item: $session) { SessionEditor(draft: $0) }
            .sheet(item: $editingSession) { item in
                SessionEditor(existing: item.session, studentId: item.studentId)
            }
            .sheet(item: $model.pendingSession) { SessionEditor(draft: $0) }
            .sheet(isPresented: $isEditingReport) { ReportEditor() }
            .alert("New student", isPresented: $isAddingStudent) {
                TextField("Name", text: $studentName)
                TextField("Subject", text: $studentSubject)
                Button("Cancel", role: .cancel) {}
                Button("Add") {
                    let name = studentName.trimmingCharacters(in: .whitespaces)
                    let subject = studentSubject.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    model.report.update { $0.addStudent(name: name, subject: subject) }
                }
            }
        }
    }

    private func sorted(_ student: Student) -> [TutoringSession] {
        student.sessions.sorted { $0.date > $1.date }
    }

    private func periodLabel(_ report: PaymentReport) -> String {
        guard !report.start.isEmpty, !report.end.isEmpty else { return "-" }
        return "\(shortDate(report.start)) - \(shortDate(report.end))"
    }

    private func row(_ session: TutoringSession, rate: Double) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.date.isEmpty ? "No date" : dayLabel(session.date))
                    .fontWeight(.medium)
                if !session.startTime.isEmpty {
                    Text(clockTime(session.startTime))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatUSD(session.hrs * rate))
                    .fontWeight(.medium)
                Text("\(formatNumber(session.hrs)) hrs")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }

    private func dayLabel(_ key: String) -> String {
        CivilDate(key: key)?.formatted("EEE, MMM d") ?? key
    }
}

struct SessionEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var studentId: Int?
    @State private var date: Date
    @State private var hasStart: Bool
    @State private var start: Date
    @State private var hours: Double
    private let existing: TutoringSession?

    init(draft: SessionDraft) {
        existing = nil
        _studentId = State(initialValue: draft.studentId ?? AppModel.shared.report.value.students.first?.id)
        _date = State(initialValue: draft.date.date())
        _hasStart = State(initialValue: draft.startMinute != nil)
        _start = State(initialValue: draft.date.date(minutes: draft.startMinute ?? 16 * 60))
        _hours = State(initialValue: draft.hours)
    }

    init(existing session: TutoringSession, studentId: Int) {
        existing = session
        _studentId = State(initialValue: studentId)
        let day = CivilDate(key: session.date)
        _date = State(initialValue: (day ?? AppModel.shared.today).date())
        let parts = session.startTime.split(separator: ":").compactMap { Int($0) }
        let minutes = parts.count == 2 ? parts[0] * 60 + parts[1] : nil
        _hasStart = State(initialValue: minutes != nil)
        _start = State(initialValue: (day ?? AppModel.shared.today).date(minutes: minutes ?? 16 * 60))
        _hours = State(initialValue: session.hrs)
    }

    var body: some View {
        let report = model.report.value
        NavigationStack {
            Form {
                Section {
                    Picker("Student", selection: $studentId) {
                        ForEach(report.students) { student in
                            Text(student.name).tag(Int?.some(student.id))
                        }
                    }
                    .accessibilityIdentifier("session.student")
                    .disabled(existing != nil)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Toggle("Start time", isOn: $hasStart)
                    if hasStart {
                        DatePicker("Starts", selection: $start, displayedComponents: .hourAndMinute)
                    }
                    Stepper(value: $hours, in: 0.25...12, step: 0.25) {
                        LabeledContent("Hours", value: formatNumber(hours))
                            .accessibilityIdentifier("session.hours")
                    }
                }
                Section {
                    LabeledContent("Amount", value: formatUSD(hours * report.rate))
                }
            }
            .navigationTitle(existing == nil ? "Log session" : "Edit session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(studentId == nil)
                        .accessibilityIdentifier("session.save")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        guard let studentId else { return }
        let session = TutoringSession(
            id: existing?.id ?? 0,
            date: CivilDate(date).key,
            startTime: hasStart ? hhmm(CivilDate.minuteOfDay(start)) : "",
            hrs: hours)
        model.report.update { $0.save(session, studentId: studentId) }
        dismiss()
    }
}

/// The report's period and rate.
struct ReportEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var start = AppModel.shared.today.date()
    @State private var end = AppModel.shared.today.date()
    @State private var rate: Double?
    @State private var every = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Period start", selection: $start, displayedComponents: .date)
                    DatePicker("Period end", selection: $end, displayedComponents: .date)
                    NumberField(title: "Hourly rate", value: $rate)
                        .accessibilityIdentifier("report.rate")
                    LabeledContent("Paid every") {
                        TextField("10th & 25th", text: $every)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .accessibilityIdentifier("report.save")
                }
            }
            .onAppear {
                let report = model.report.value
                if let day = CivilDate(key: report.start) { start = day.date() }
                if let day = CivilDate(key: report.end) { end = day.date() }
                rate = report.rate
                every = report.every
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        let startKey = CivilDate(start).key
        let endKey = CivilDate(end).key
        let rate = rate ?? 0
        let every = every
        model.report.update {
            $0.start = startKey
            $0.end = endKey
            $0.rate = rate
            $0.every = every
        }
        dismiss()
    }
}
