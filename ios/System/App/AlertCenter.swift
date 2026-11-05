import Foundation
import SystemCore
import UserNotifications

/// What someone did with a notification.
struct AlertResponse: Sendable {
    enum Action: Sendable {
        case open, extend, skip, logSession
    }

    let action: Action
    let date: CivilDate
    let skipBlockId: Int?
    let extendBlockId: Int?
    let tutoringBlockId: Int?
}

/// Puts planned alerts on the phone. They fire with the app closed and need no
/// server or signal, which is why alerts live here and not in the cloud.
final class AlertCenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AlertCenter()

    nonisolated private enum Category {
        static let soon = "soon"
        static let soonRunning = "soon.running"
        static let timesUp = "up"
        static let timesUpTutoring = "up.tutoring"
    }

    nonisolated private enum Action {
        static let extend = "extend"
        static let skip = "skip"
        static let log = "log"
    }

    nonisolated private enum Key {
        static let date = "date"
        static let skip = "skipBlockId"
        static let extend = "extendBlockId"
        static let tutoring = "tutoringBlockId"
    }

    private var center: UNUserNotificationCenter { .current() }

    func activate() {
        center.delegate = self
        let extend = UNNotificationAction(identifier: Action.extend, title: "+15 min", options: [])
        let skip = UNNotificationAction(identifier: Action.skip, title: "Skip today", options: [])
        let log = UNNotificationAction(identifier: Action.log, title: "Log session", options: [.foreground])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Category.soon, actions: [skip], intentIdentifiers: []),
            UNNotificationCategory(identifier: Category.soonRunning, actions: [extend, skip], intentIdentifiers: []),
            UNNotificationCategory(identifier: Category.timesUp, actions: [extend], intentIdentifiers: []),
            UNNotificationCategory(
                identifier: Category.timesUpTutoring, actions: [log, extend], intentIdentifiers: []),
        ])
    }

    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func isAllowed() async -> Bool {
        await center.notificationSettings().authorizationStatus == .authorized
    }

    /// An alert waiting on the phone.
    struct Pending {
        let title: String
        let time: String
    }

    /// The soonest alert the system actually has queued.
    func next(after date: Date) async -> Pending? {
        let calendar = Calendar.current
        let upcoming = await center.pendingNotificationRequests().compactMap { request -> (Date, String)? in
            guard request.identifier != E2ESeed.testAlertId,
                let trigger = request.trigger as? UNCalendarNotificationTrigger,
                let fire = calendar.date(from: trigger.dateComponents), fire > date
            else { return nil }
            return (fire, request.content.title)
        }
        guard let soonest = upcoming.min(by: { $0.0 < $1.0 }) else { return nil }
        let isToday = calendar.isDate(soonest.0, inSameDayAs: date)
        let time = clockLabel(CivilDate.minuteOfDay(soonest.0))
        let day = isToday ? "" : "\(CivilDate(soonest.0).formatted("EEE")) "
        return Pending(title: soonest.1, time: day + time)
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
        }
    }

    private func makeRequest(_ alert: PlannedAlert) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.body
        content.sound = .default
        content.categoryIdentifier = category(for: alert)
        var info: [String: Any] = [Key.date: alert.date.key]
        if let id = alert.skipBlockId { info[Key.skip] = id }
        if let id = alert.extendBlockId { info[Key.extend] = id }
        if let id = alert.tutoringBlockId { info[Key.tutoring] = id }
        content.userInfo = info

        var parts = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: alert.fireDate)
        parts.second = 0
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

    private func category(for alert: PlannedAlert) -> String {
        switch alert.kind {
        case .startingSoon: alert.extendBlockId == nil ? Category.soon : Category.soonRunning
        case .timesUp: alert.tutoringBlockId == nil ? Category.timesUp : Category.timesUpTutoring
        case .morningSummary, .keepAlive: ""
        }
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
            case Action.log: .logSession
            default: .open
            }
        let date = (info[Key.date] as? String).flatMap(CivilDate.init(key:)) ?? CivilDate(Date())
        return AlertResponse(
            action: action,
            date: date,
            skipBlockId: info[Key.skip] as? Int,
            extendBlockId: info[Key.extend] as? Int,
            tutoringBlockId: info[Key.tutoring] as? Int)
    }
}
