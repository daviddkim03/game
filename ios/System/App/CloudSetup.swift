import Foundation
import SystemCore

/// The same Firebase project as the website. This is public client config, like
/// src/lib/firebase-config.ts: the data is protected by sign-in and the rules.
enum CloudSetup {
    static let config = CloudConfig.production(
        apiKey: "AIzaSyAmEyvqbZDNedW-r9-WzrRODoQZQjKts-g",
        projectId: "game-7487d"
    )

    /// The account this build signs in to, so it only has to ask for the
    /// password. It's set at build time because this repo is public. Without
    /// one, sign-in asks for the email too.
    static let account: String = {
        guard !ProcessInfo.processInfo.arguments.contains("-noAccount") else { return "" }
        return Bundle.main.object(forInfoDictionaryKey: "SystemAccount") as? String ?? ""
    }()
}
