import BackgroundTasks
import SwiftUI

@main
struct SystemApp: App {
    @State private var model = AppModel.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        AlertCenter.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background { AppModel.requestBackgroundRefresh() }
                }
        }
        .backgroundTask(.appRefresh(AppModel.refreshTaskId)) {
            await AppModel.shared.backgroundRefresh()
        }
    }
}
