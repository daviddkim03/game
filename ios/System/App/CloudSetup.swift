import SystemCore

/// The same Firebase project as the website. This is public client config, like
/// src/lib/firebase-config.ts: the data is protected by sign-in and the rules.
enum CloudSetup {
    static let config = CloudConfig.production(
        apiKey: "AIzaSyAmEyvqbZDNedW-r9-WzrRODoQZQjKts-g",
        projectId: "game-7487d"
    )

    /// The only account, so signing in just takes its password. It's the one
    /// in `firebaseLoginUsers` on the website.
    static let account = "admin@app.local"
}
