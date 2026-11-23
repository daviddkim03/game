import Foundation

/// The current time. UI tests pin it with `-nowAt 2026-11-05T09:58` so the
/// screens they check don't depend on when they run.
enum AppClock {
    /// How far ahead of the phone's clock this one runs. Whole seconds, because
    /// notification times have no fractions.
    private static let offset: TimeInterval = {
        guard let text = UserDefaults.standard.string(forKey: "nowAt") else { return 0 }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        // Up, so the clock never starts a moment before the pinned time.
        return (formatter.date(from: text)?.timeIntervalSinceNow ?? 0).rounded(.up)
    }()

    static var now: Date {
        Date().addingTimeInterval(offset)
    }

    /// What the phone's own clock, which notifications go by, says at `date`.
    static func phoneTime(at date: Date) -> Date {
        date.addingTimeInterval(-offset)
    }

    /// What this clock says when the phone's says `phoneTime`.
    static func time(atPhoneTime phoneTime: Date) -> Date {
        phoneTime.addingTimeInterval(offset)
    }
}
