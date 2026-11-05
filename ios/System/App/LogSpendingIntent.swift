import AppIntents
import SystemCore

/// The action a Shortcuts automation runs on each Apple Pay tap. Amount is text
/// so whatever Shortcuts hands over ("$12.34", "12.34") can be read.
struct LogSpendingIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Spending"
    static let description = IntentDescription("Adds a purchase to this month's spending in System.")
    static let openAppWhenRun = false

    @Parameter(title: "Amount")
    var amount: String

    @Parameter(title: "Merchant")
    var merchant: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount) at \(\.$merchant)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let value = parseAmount(amount) else {
            throw $amount.needsValueError("What was the amount?")
        }
        let name = (merchant ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let isSaved = await AppModel.shared.logSpending(
            amount: value,
            merchant: name.isEmpty ? "Apple Pay" : name,
            source: .applePay)
        let summary = isSaved ? "Logged \(formatUSD(value, cents: true))" : "Already logged"
        return .result(dialog: IntentDialog(stringLiteral: summary))
    }
}

struct SystemShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogSpendingIntent(),
            phrases: ["Log spending in \(.applicationName)"],
            shortTitle: "Log Spending",
            systemImageName: "creditcard")
    }
}
