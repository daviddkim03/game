import SwiftUI
import SystemCore
import UIKit

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    private let alerts = AlertCenter.shared

    private var isNotifying: Bool {
        model.phone.value.areAlertsOn
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Notifications", isOn: notifications)
                        .accessibilityIdentifier("settings.notifications")
                    if isNotifying {
                        if !alerts.isAllowed {
                            Button("Allow in iPhone Settings") {
                                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                                    openURL(url)
                                }
                            }
                            .accessibilityIdentifier("settings.allow")
                        } else if let next = alerts.next {
                            LabeledContent("Next alert") {
                                Text("\(next.title), \(next.time)")
                                    .accessibilityIdentifier("settings.nextAlert")
                            }
                        }
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
            .animation(.default, value: isNotifying)
            .animation(.default, value: alerts.isAllowed)
            .animation(.default, value: alerts.next)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var notifications: Binding<Bool> {
        Binding(
            get: { isNotifying },
            set: { isOn in model.phone.update { $0.areAlertsOn = isOn } })
    }
}
