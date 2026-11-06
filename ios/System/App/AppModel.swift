import BackgroundTasks
import Foundation
import Observation
import SystemCore
import WidgetKit

enum AppTab: Hashable {
    case now, calendar, budget
}

/// One block on one date, for sheets and notification actions.
struct BlockRef: Identifiable, Hashable {
    let date: CivilDate
    let blockId: Int
    var id: String { "\(date.key)-\(blockId)" }
}

/// Holds the signed-in state and every cloud page, and runs anything that has
/// to reach more than one of them.
@MainActor
@Observable
final class AppModel {
    enum Auth: Equatable {
        case loading
        case signedOut
        case signedIn(String)
    }

    static let shared = AppModel()
    nonisolated static let refreshTaskId = "com.daviddkim03.system.refresh"
    static let isE2E = ProcessInfo.processInfo.arguments.contains("-e2e")

    private(set) var auth: Auth = .loading
    var tab: AppTab = .now

    let schedule: DocumentStore<Schedule>
    let phone: DocumentStore<PhonePrefs>
    let tracker: DocumentStore<TrackerData>

    @ObservationIgnored private let backend: CloudBackend
    @ObservationIgnored private let cache: DocumentCache
    @ObservationIgnored private var alertTask: Task<Void, Never>?

    private let widget = WidgetStore.shared

    private init() {
        let backend: CloudBackend
        let cache: DocumentCache
        if Self.isE2E {
            backend = E2ESeed.backend()
            cache = MemoryCache()
        } else {
            backend = FirebaseBackend(config: CloudSetup.config, store: KeychainSessionStore())
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            cache = FileDocumentCache(directory: support.appendingPathComponent("cloud"))
        }
        self.backend = backend
        self.cache = cache
        schedule = DocumentStore(pageId: "schedule", backend: backend, cache: cache)
        phone = DocumentStore(pageId: PhonePrefs.pageId, backend: backend, cache: cache)
        tracker = DocumentStore(pageId: "game_tracker", backend: backend, cache: cache)

        schedule.onChange = { [weak self] in self?.syncAlerts() }
        phone.onChange = { [weak self] in self?.syncAlerts() }
        Task { await loadSession() }
    }

    var today: CivilDate {
        CivilDate(AppClock.now)
    }

    /// The first problem any page is having, to show as a banner.
    var syncIssue: SyncIssue? {
        [schedule.issue, phone.issue, tracker.issue]
            .compactMap { $0 }
            .first
    }

    var signedInEmail: String? {
        if case .signedIn(let email) = auth { return email }
        return nil
    }

    // MARK: Session

    private func loadSession() async {
        if let email = await backend.currentEmail() {
            auth = .signedIn(email)
            await refreshAll()
        } else {
            auth = .signedOut
        }
    }

    func signIn(email: String, password: String) async throws {
        try await backend.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password)
        auth = await backend.currentEmail().map(Auth.signedIn) ?? .signedOut
        await refreshAll()
    }

    func signOut() async {
        await backend.signOut()
        cache.clear()
        schedule.reset()
        phone.reset()
        tracker.reset()
        await AlertCenter.shared.replace(with: [])
        widget.clear()
        WidgetCenter.shared.reloadAllTimelines()
        auth = .signedOut
    }

    // MARK: Sync

    func refreshAll() async {
        guard signedInEmail != nil else { return }
        async let a: Void = schedule.refresh()
        async let b: Void = phone.refresh()
        async let c: Void = tracker.refresh()
        _ = await (a, b, c)
        // Local copies stay put, so unsaved edits go up after signing back in.
        if syncIssue == .sessionExpired { auth = .signedOut }
        syncAlerts()
    }

    func backgroundRefresh() async {
        Self.requestBackgroundRefresh()
        await refreshAll()
        await alertTask?.value
    }

    nonisolated static func requestBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    // MARK: Schedule

    func plan(for date: CivilDate) -> DayPlan {
        dayPlan(for: date, schedule: schedule.value, override: phone.value.days[date.key])
    }

    func skip(_ blockId: Int, on date: CivilDate) {
        let today = today
        phone.update {
            $0.skip(blockId, on: date)
            $0.prune(today: today)
        }
    }

    func restore(_ blockId: Int, on date: CivilDate) {
        phone.update { $0.restore(blockId, on: date) }
    }

    func addFifteen(to blockId: Int, on date: CivilDate) {
        phone.update { $0.extend(blockId, on: date, by: 15) }
    }

    func undoFifteen(from blockId: Int, on date: CivilDate) {
        phone.update { $0.extend(blockId, on: date, by: -15) }
    }

    // MARK: Alerts

    /// Replaces the phone's pending alerts shortly after anything changes.
    func syncAlerts() {
        let previous = alertTask
        previous?.cancel()
        alertTask = Task {
            // One at a time, so an older pass can't finish after a newer one.
            await previous?.value
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            await replaceAlerts()
        }
    }

    private func replaceAlerts() async {
        guard signedInEmail != nil, schedule.isLoaded else { return }
        if widget.write(WidgetSnapshot(schedule: schedule.value, days: phone.value.days)) {
            WidgetCenter.shared.reloadAllTimelines()
        }
        let extras = E2ESeed.extraAlerts(today: today, plan: plan(for: today))
        let alerts = AlertPlanner.plan(
            schedule: schedule.value,
            days: phone.value.days,
            prefs: phone.value.alerts,
            now: AppClock.now,
            limit: AlertPlanner.systemLimit - extras.count)
        await AlertCenter.shared.replace(with: alerts + extras)
    }

    /// Runs what a notification's button asked for.
    func handle(_ response: AlertResponse) async {
        if !isReady { await loadSession() }
        switch response.action {
        case .extend:
            if let id = response.extendBlockId { addFifteen(to: id, on: response.date) }
            await finishInBackground()
        case .skip:
            if let id = response.skipBlockId { skip(id, on: response.date) }
            await finishInBackground()
        case .open:
            tab = .now
        }
    }

    /// iOS may suspend the app as soon as a notification button's work returns,
    /// so this saves and moves the alerts before that happens.
    private func finishInBackground() async {
        await phone.flush()
        syncAlerts()
        await alertTask?.value
    }

    private var isReady: Bool {
        signedInEmail != nil
    }
}
