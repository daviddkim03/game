import Foundation

/// The current time. UI tests pin it with `-nowAt 2026-11-05T09:58` so the
/// screens they check don't depend on when they run.
enum AppClock {
    private static let offset: TimeInterval = {
        guard let text = UserDefaults.standard.string(forKey: "nowAt") else { return 0 }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter.date(from: text)?.timeIntervalSinceNow ?? 0
    }()

    static var now: Date {
        Date().addingTimeInterval(offset)
    }
}
