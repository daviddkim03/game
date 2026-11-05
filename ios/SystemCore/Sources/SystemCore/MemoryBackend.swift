import Foundation

/// In-memory stand-in for Firebase, for tests and the app's `-e2e` mode.
public actor MemoryBackend: CloudBackend {
    public private(set) var documents: [String: CloudDocument]
    public private(set) var saves: [String: Int] = [:]
    private var email: String?
    private var version = 0
    /// While true, every request fails as if there were no connection.
    public var isOffline = false
    /// How long a save takes, for tests that need one to be in progress.
    public var saveDelay: Duration?
    /// How long a load takes, for tests that need one to be in progress.
    public var loadDelay: Duration?

    public init(documents: [String: JSONValue] = [:], signedInAs email: String? = "e2e@example.com") {
        self.documents = documents.mapValues { CloudDocument(data: $0, updateTime: "v0") }
        self.email = email
    }

    public func setOffline(_ offline: Bool) {
        isOffline = offline
    }

    public func setSaveDelay(_ delay: Duration?) {
        saveDelay = delay
    }

    public func setLoadDelay(_ delay: Duration?) {
        loadDelay = delay
    }

    /// Changes a document the way another device would.
    public func receive(_ pageId: String, data: JSONValue) {
        documents[pageId] = CloudDocument(data: data, updateTime: nextVersion())
    }

    public func currentEmail() -> String? {
        email
    }

    public func signIn(email: String, password: String) throws {
        guard !isOffline else { throw CloudError.offline }
        guard password == "password" else { throw CloudError.invalidCredentials }
        self.email = email
    }

    public func signOut() {
        email = nil
    }

    public func load(_ pageId: String) async throws -> CloudDocument? {
        guard !isOffline else { throw CloudError.offline }
        let document = documents[pageId]
        // The copy is read now but arrives later, like a slow network.
        if let loadDelay { try await Task.sleep(for: loadDelay) }
        return document
    }

    public func save(
        _ pageId: String,
        data: JSONValue,
        precondition: SavePrecondition
    ) async throws -> String {
        if let saveDelay { try await Task.sleep(for: saveDelay) }
        guard !isOffline else { throw CloudError.offline }
        switch precondition {
        case .unchangedSince(let expected):
            guard documents[pageId]?.updateTime == expected else { throw CloudError.conflict }
        case .missing:
            guard documents[pageId] == nil else { throw CloudError.conflict }
        case .none:
            break
        }
        let updateTime = nextVersion()
        documents[pageId] = CloudDocument(data: data, updateTime: updateTime)
        saves[pageId, default: 0] += 1
        return updateTime
    }

    private func nextVersion() -> String {
        version += 1
        return "v\(version)"
    }
}
