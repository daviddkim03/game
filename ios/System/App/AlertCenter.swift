import Foundation
import Observation
import SystemCore
import UserNotifications

/// What someone did with a notification.
struct AlertResponse: Sendable {
    enum Action: Sendable {
        case open, extend, skip
    }

    let action: Action
    let date: CivilDate
    let skipBlockId: Int?
    let extendBlockId: Int?
}

/// Puts planned alerts on the phone. They fire with the app closed and need no
/// server or signal, which is why alerts live here and not in the cloud.
@Observable
final class AlertCenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AlertCenter()

    /// Whether iOS lets the app notify.
    private(set) var isAllowed = true
    /// The soonest alert iOS actually has queued.
    private(set) var next: Pending?

    /// An alert waiting on the phone.
    struct Pending: Equatable {
        let title: String
        let time: String
    }

    nonisolated private enum Category {
        static let soon = "soon"
        static let soonRunning = "soon.running"
    }

    nonisolated private enum Action {
        static let extend = "extend"
        static let skip = "skip"
    }

    nonisolated private enum Key {
        static let date = "date"
        static let skip = "skipBlockId"
        static let extend = "extendBlockId"
    }

    private var center: UNUserNotificationCenter { .current() }

    func activate() {
        center.delegate = self
        let extend = UNNotificationAction(identifier: Action.extend, title: "+15 min", options: [])
        let skip = UNNotificationAction(identifier: Action.skip, title: "Skip today", options: [])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Category.soon, actions: [skip], intentIdentifiers: []),
            UNNotificationCategory(identifier: Category.soonRunning, actions: [extend, skip], intentIdentifiers: []),
        ])
    }

    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Makes the phone's queue match `alerts`, touching only what changed. This
    /// runs on every sync, and clearing the queue each time could lose an alert
    /// due at that moment.
    func replace(with alerts: [PlannedAlert]) async {
        let pending = await center.pendingNotificationRequests()
        let wanted = Set(alerts.map(\.id))
        // Stale ones go first: past 64, iOS silently drops the oldest added.
        center.removePendingNotificationRequests(
            withIdentifiers: pending.map(\.identifier).filter { !wanted.contains($0) })

        let current = Dictionary(pending.map { ($0.identifier, $0) }, uniquingKeysWith: { first, _ in first })
        for alert in alerts {
            guard !Task.isCancelled else { return }
            let request = makeRequest(alert)
            if let existing = current[alert.id], isSame(existing, request) { continue }
            try? await center.add(request)
            // iOS takes a second or two over a full queue, and this one is all
            // that Settings shows.
            if alert.id == alerts.first?.id { await readBack() }
        }
        await readBack()
    }

    private func readBack() async {
        let settings = await center.notificationSettings()
        isAllowed = settings.authorizationStatus == .authorized || !AppModel.asksForAlerts
        next = await soonest()
    }

    private func soonest() async -> Pending? {
        let calendar = Calendar.current
        let now = AppClock.now
        let upcoming = await center.pendingNotificationRequests().compactMap { request -> (Date, String)? in
            guard let trigger = request.trigger as? UNCalendarNotificationTrigger,
                let phoneTime = calendar.date(from: trigger.dateComponents)
            else { return nil }
            let fire = AppClock.time(atPhoneTime: phoneTime)
            return fire > now ? (fire, request.content.title) : nil
        }
        guard let soonest = upcoming.min(by: { $0.0 < $1.0 }) else { return nil }
        let isToday = calendar.isDate(soonest.0, inSameDayAs: now)
        let time = clockLabel(CivilDate.minuteOfDay(soonest.0))
        let day = isToday ? "" : "\(CivilDate(soonest.0).formatted("EEE")) "
        return Pending(title: soonest.1, time: day + time)
    }

    private func makeRequest(_ alert: PlannedAlert) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.body
        content.sound = .default
        content.categoryIdentifier = alert.extendBlockId == nil ? Category.soon : Category.soonRunning
        var info: [String: Any] = [Key.date: alert.date.key, Key.skip: alert.skipBlockId]
        if let id = alert.extendBlockId { info[Key.extend] = id }
        content.userInfo = info

        let parts = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: AppClock.phoneTime(at: alert.fireDate))
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        return UNNotificationRequest(identifier: alert.id, content: content, trigger: trigger)
    }

    private func isSame(_ first: UNNotificationRequest, _ second: UNNotificationRequest) -> Bool {
        let (a, b) = (first.content, second.content)
        let firstTrigger = first.trigger as? UNCalendarNotificationTrigger
        let secondTrigger = second.trigger as? UNCalendarNotificationTrigger
        return a.title == b.title && a.body == b.body
            && a.categoryIdentifier == b.categoryIdentifier
            && firstTrigger?.dateComponents == secondTrigger?.dateComponents
            && NSDictionary(dictionary: a.userInfo).isEqual(to: b.userInfo)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    /// UIKit crashes unless this finishes on the main thread, which rules out
    /// the async form of this method: it returns on a background thread.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let result = Self.parse(response)
        nonisolated(unsafe) let finish = completionHandler
        Task { @MainActor in
            await AppModel.shared.handle(result)
            finish()
        }
    }

    nonisolated private static func parse(_ response: UNNotificationResponse) -> AlertResponse {
        let info = response.notification.request.content.userInfo
        let action: AlertResponse.Action =
            switch response.actionIdentifier {
            case Action.extend: .extend
            case Action.skip: .skip
            default: .open
            }
        let date = (info[Key.date] as? String).flatMap(CivilDate.init(key:)) ?? CivilDate(Date())
        return AlertResponse(
            action: action,
            date: date,
            skipBlockId: info[Key.skip] as? Int,
            extendBlockId: info[Key.extend] as? Int)
    }
}
