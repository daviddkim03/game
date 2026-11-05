import SystemCore

/// The same Firebase project as the website. This is public client config, like
/// src/lib/firebase-config.ts: the data is protected by sign-in and the rules.
enum CloudSetup {
    static let config = CloudConfig.production(
        apiKey: "AIzaSyAmEyvqbZDNedW-r9-WzrRODoQZQjKts-g",
        projectId: "game-7487d"
    )

    /// Short sign-in names, as in `firebaseLoginUsers` on the website.
    static let aliases = ["admin": "admin@app.local"]
}
