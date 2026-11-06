import SwiftUI
import SystemCore

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        switch model.auth {
        case .loading:
            ProgressView()
        case .signedOut:
            SignInView()
        case .signedIn:
            MainTabs()
        }
    }
}

struct MainTabs: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasAskedForAlerts = false

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.tab) {
            Tab("Now", systemImage: "clock", value: AppTab.now) {
                NowView()
            }
            Tab("Calendar", systemImage: "calendar", value: AppTab.calendar) {
                CalendarScreen()
            }
            Tab("Budget", systemImage: "dollarsign.circle", value: AppTab.budget) {
                BudgetScreen()
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            SyncBanner()
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            if !hasAskedForAlerts, !AppModel.isE2E || ProcessInfo.processInfo.arguments.contains("-askAlerts") {
                hasAskedForAlerts = true
                _ = await AlertCenter.shared.requestPermission()
                model.syncAlerts()
            }
            // The cloud has no push to the phone, so look while the app is open.
            while !Task.isCancelled {
                await model.refreshAll()
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }
}

/// Says so when changes can't reach the cloud. Local edits are safe either way.
struct SyncBanner: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let message {
            Text(message)
                .font(.footnote.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(.orange.opacity(0.2))
                .accessibilityIdentifier("sync.banner")
        }
    }

    private var message: String? {
        switch model.syncIssue {
        case .offline: "Offline. Changes will sync later."
        case .denied: "This account can't reach your data."
        case .failed: "Couldn't sync. Will keep trying."
        case .sessionExpired, nil: nil
        }
    }
}
