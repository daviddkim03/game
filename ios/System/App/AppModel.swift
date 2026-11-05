import BackgroundTasks
import Foundation
import Observation
import SystemCore

enum AppTab: Hashable {
    case now, calendar, budget, tutoring
}

/// One block on one date, for sheets and notification actions.
struct BlockRef: Identifiable, Hashable {
    let date: CivilDate
    let blockId: Int
    var id: String { "\(date.key)-\(blockId)" }
}

/// A session waiting to be logged, prefilled from a schedule block.
struct SessionDraft: Identifiable, Hashable {
    let id = UUID()
    var studentId: Int?
    var date: CivilDate
    var startMinute: Int?
    var hours: Double
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
    /// Set by a notification's "Log session" button.
    var pendingSession: SessionDraft?

    let schedule: DocumentStore<Schedule>
    let phone: DocumentStore<PhonePrefs>
    let tracker: DocumentStore<TrackerData>
    let report: DocumentStore<PaymentReport>

    @ObservationIgnored private let backend: CloudBackend
    @ObservationIgnored private let cache: DocumentCache
    @ObservationIgnored private var spendingStores: [String: DocumentStore<SpendingMonth>] = [:]
    @ObservationIgnored private var alertTask: Task<Void, Never>?

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
        report = DocumentStore(pageId: "payment_report", backend: backend, cache: cache)

        schedule.onChange = { [weak self] in self?.syncAlerts() }
        phone.onChange = { [weak self] in self?.syncAlerts() }
        report.onChange = { [weak self] in self?.syncAlerts() }
        Task { await loadSession() }
    }

    var today: CivilDate {
        CivilDate(AppClock.now)
    }

    /// The first problem any page is having, to show as a banner.
    var syncIssue: SyncIssue? {
        [schedule.issue, phone.issue, tracker.issue, report.issue]
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

    func signIn(password: String) async throws {
        try await backend.signIn(email: CloudSetup.account, password: password)
        auth = await backend.currentEmail().map(Auth.signedIn) ?? .signedOut
        await refreshAll()
    }

    func signOut() async {
        await backend.signOut()
        cache.clear()
        schedule.reset()
        phone.reset()
        tracker.reset()
        report.reset()
        spendingStores = [:]
        await AlertCenter.shared.replace(with: [])
        auth = .signedOut
    }

    // MARK: Sync

    func refreshAll() async {
        guard signedInEmail != nil else { return }
        async let a: Void = schedule.refresh()
        async let b: Void = phone.refresh()
        async let c: Void = tracker.refresh()
        async let d: Void = report.refresh()
        async let e: Void = spending(for: today).refresh()
        _ = await (a, b, c, d, e)
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

    func spending(for date: CivilDate) -> DocumentStore<SpendingMonth> {
        let pageId = SpendingMonth.pageId(date)
        if let store = spendingStores[pageId] { return store }
        let store = DocumentStore<SpendingMonth>(pageId: pageId, backend: backend, cache: cache)
        spendingStores[pageId] = store
        Task { await store.refresh() }
        return store
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

    /// Prefills a session from a block, using the student its label names.
    func sessionDraft(for block: PlannedBlock, on date: CivilDate) -> SessionDraft {
        SessionDraft(
            studentId: report.value.student(matching: block.label)?.id,
            date: date,
            startMinute: block.start,
            hours: Double(block.end - block.start) / 60)
    }

    // MARK: Spending

    /// Adds a purchase and waits for it to be saved. Returns false when it
    /// repeats one just logged.
    @discardableResult
    func logSpending(
        amount: Double,
        merchant: String,
        category: String? = nil,
        source: SpendEntry.Source = .manual,
        date: Date = AppClock.now
    ) async -> Bool {
        let store = spending(for: CivilDate(date))
        await store.refresh()
        if source == .applePay,
            store.value.hasDuplicate(amount: amount, merchant: merchant, near: date)
        {
            return false
        }
        let remembered = phone.value.merchantCategories[merchant.lowercased()]
        let entry = SpendEntry(
            date: date, amount: amount, merchant: merchant,
            category: category ?? remembered, source: source)
        store.update { $0.add(entry) }
        await store.flush()
        return true
    }

    /// Saves a purchase and remembers its merchant's category for next time.
    func saveSpending(_ entry: SpendEntry, replacing original: SpendEntry? = nil) {
        // Each month is its own document, so a new date can mean a new home.
        if let original, SpendingMonth.pageId(CivilDate(original.date)) != SpendingMonth.pageId(CivilDate(entry.date)) {
            deleteSpending(original)
        }
        spending(for: CivilDate(entry.date)).update { $0.save(entry) }
        let key = entry.merchant.lowercased()
        guard !key.isEmpty, let category = entry.category,
            phone.value.merchantCategories[key] != category
        else { return }
        phone.update { $0.merchantCategories[key] = category }
    }

    func deleteSpending(_ entry: SpendEntry) {
        spending(for: CivilDate(entry.date)).update { $0.delete(entry.id) }
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
        let report = report.value
        let extras = E2ESeed.extraAlerts(today: today, plan: plan(for: today))
        let alerts = AlertPlanner.plan(
            schedule: schedule.value,
            days: phone.value.days,
            prefs: phone.value.alerts,
            now: AppClock.now,
            isTutoring: report.isTutoring,
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
        case .logSession:
            tab = .tutoring
            if let id = response.tutoringBlockId,
                let block = plan(for: response.date).blocks.first(where: { $0.id == id })
            {
                pendingSession = sessionDraft(for: block, on: response.date)
            }
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
