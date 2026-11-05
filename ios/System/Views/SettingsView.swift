import SwiftUI
import SystemCore
import UIKit

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var areAlertsAllowed = true
    @State private var nextAlert: AlertCenter.Pending?

    private var labels: [String] {
        Array(Set(model.schedule.value.blocks.map(\.label)))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Alerts") {
                    if !areAlertsAllowed {
                        Button("Turn on notifications") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                    Toggle("5 min before the next thing", isOn: prefs(\.startingSoon))
                        .accessibilityIdentifier("settings.soon")
                    Toggle("Time's up", isOn: prefs(\.timesUp))
                        .accessibilityIdentifier("settings.timesUp")
                    Toggle("Morning summary", isOn: prefs(\.morningSummary))
                        .accessibilityIdentifier("settings.morning")
                    if model.phone.value.alerts.morningSummary {
                        DatePicker("Summary time", selection: morningTime, displayedComponents: .hourAndMinute)
                    }
                    if let nextAlert {
                        LabeledContent("Next alert") {
                            Text("\(nextAlert.title), \(nextAlert.time)")
                                .accessibilityIdentifier("settings.nextAlert")
                        }
                    }
                }

                if !labels.isEmpty {
                    Section("Alert me for") {
                        ForEach(labels, id: \.self) { label in
                            Toggle(label, isOn: isAlerting(label))
                                .accessibilityIdentifier("settings.alert.\(label)")
                        }
                    }
                }

                Section("Spending") {
                    NavigationLink("Log Apple Pay automatically") {
                        ApplePaySetupView()
                    }
                }

                Section("Account") {
                    if let email = model.signedInEmail {
                        LabeledContent("Signed in as", value: email)
                    }
                    Button("Sign out", role: .destructive) {
                        Task {
                            await model.signOut()
                            dismiss()
                        }
                    }
                    .accessibilityIdentifier("settings.signOut")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task(id: model.phone.value) {
                areAlertsAllowed = await AlertCenter.shared.isAllowed() || AppModel.isE2E
                try? await Task.sleep(for: .milliseconds(400))
                nextAlert = await AlertCenter.shared.next(after: AppClock.now)
            }
        }
    }

    private func prefs(_ path: WritableKeyPath<AlertPrefs, Bool>) -> Binding<Bool> {
        Binding(
            get: { model.phone.value.alerts[keyPath: path] },
            set: { value in model.phone.update { $0.alerts[keyPath: path] = value } })
    }

    private func isAlerting(_ label: String) -> Binding<Bool> {
        Binding(
            get: { !model.phone.value.alerts.muted.contains(label) },
            set: { isOn in
                model.phone.update {
                    if isOn {
                        $0.alerts.muted.remove(label)
                    } else {
                        $0.alerts.muted.insert(label)
                    }
                }
            })
    }

    private var morningTime: Binding<Date> {
        Binding(
            get: { model.today.date(minutes: model.phone.value.alerts.morningMinute) },
            set: { date in
                model.phone.update { $0.alerts.morningMinute = CivilDate.minuteOfDay(date) }
            })
    }
}

/// iOS only lets people create automations by hand, so this walks through it.
struct ApplePaySetupView: View {
    private let steps = [
        "Open Shortcuts and go to Automation.",
        "Tap +, then choose Wallet (or Transaction).",
        "Pick your cards and choose Run Immediately.",
        "Add the Log Spending action from System.",
        "Set Amount to Shortcut Input's Amount, and Merchant to its Merchant.",
    ]

    var body: some View {
        List {
            Section {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                        Text(step)
                    }
                }
            } footer: {
                Text("Works for in-store Apple Pay. Purchases online or on a physical card need adding by hand.")
            }
            Section {
                Button("Open Shortcuts") {
                    if let url = URL(string: "shortcuts://") {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
        .navigationTitle("Apple Pay")
        .navigationBarTitleDisplayMode(.inline)
    }
}
