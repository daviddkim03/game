import Foundation

/// One saved page: its data and the version that data came from.
public struct CloudDocument: Equatable, Sendable {
    public var data: JSONValue
    public var updateTime: String

    public init(data: JSONValue, updateTime: String) {
        self.data = data
        self.updateTime = updateTime
    }
}

/// What must be true of the cloud copy for a save to go through.
public enum SavePrecondition: Equatable, Sendable {
    /// Nobody has saved since this version.
    case unchangedSince(String)
    /// The document does not exist yet.
    case missing
    /// Save regardless.
    case none
}

public enum CloudError: Error, Equatable, Sendable {
    case invalidCredentials
    case tooManyAttempts
    /// The saved session no longer works, so the person has to sign in again.
    case sessionExpired
    case offline
    /// Another device saved first.
    case conflict
    case denied
    case server(String)
}

/// Where page documents live: Firebase normally, in memory under test.
public protocol CloudBackend: Sendable {
    func currentEmail() async -> String?
    func signIn(email: String, password: String) async throws
    func signOut() async
    func load(_ pageId: String) async throws -> CloudDocument?
    /// Returns the version the document is at after this save.
    func save(
        _ pageId: String,
        data: JSONValue,
        precondition: SavePrecondition
    ) async throws -> String
}

public struct StoredSession: Codable, Equatable, Sendable {
    public var email: String
    public var refreshToken: String

    public init(email: String, refreshToken: String) {
        self.email = email
        self.refreshToken = refreshToken
    }
}

/// Keeps the sign-in between launches. The password itself is never stored.
public protocol SessionStore: Sendable {
    func read() -> StoredSession?
    func write(_ session: StoredSession?)
}

public struct CloudConfig: Sendable {
    public var apiKey: String
    public var projectId: String
    public var identityBase: String
    public var tokenBase: String
    public var firestoreBase: String
    public var collection = "personal_app_state"
    public var syncId = "main"

    public static func production(apiKey: String, projectId: String) -> CloudConfig {
        CloudConfig(
            apiKey: apiKey,
            projectId: projectId,
            identityBase: "https://identitytoolkit.googleapis.com",
            tokenBase: "https://securetoken.googleapis.com",
            firestoreBase: "https://firestore.googleapis.com"
        )
    }

    /// The local Firebase emulators, which speak the same REST APIs.
    public static func emulator(projectId: String, authPort: Int, firestorePort: Int) -> CloudConfig {
        CloudConfig(
            apiKey: "emulator",
            projectId: projectId,
            identityBase: "http://127.0.0.1:\(authPort)/identitytoolkit.googleapis.com",
            tokenBase: "http://127.0.0.1:\(authPort)/securetoken.googleapis.com",
            firestoreBase: "http://127.0.0.1:\(firestorePort)"
        )
    }
}

/// Firebase over its public REST APIs, signed in as the app's one user. Reads
/// and writes go through the same security rules as the website.
public actor FirebaseBackend: CloudBackend {
    private let config: CloudConfig
    private let store: SessionStore
    private let urlSession: URLSession
    private var stored: StoredSession?
    private var idToken: String?
    private var idTokenExpiry = Date.distantPast

    public init(config: CloudConfig, store: SessionStore, urlSession: URLSession = .shared) {
        self.config = config
        self.store = store
        self.urlSession = urlSession
        self.stored = store.read()
    }

    public func currentEmail() -> String? {
        stored?.email
    }

    public func signIn(email: String, password: String) async throws {
        let body: JSONValue = [
            "email": .string(email),
            "password": .string(password),
            "returnSecureToken": true,
        ]
        let url = "\(config.identityBase)/v1/accounts:signInWithPassword?key=\(config.apiKey)"
        let (json, status) = try await post(url, json: body)
        guard status == 200,
            let token = json["idToken"]?.stringValue,
            let refresh = json["refreshToken"]?.stringValue
        else { throw Self.authError(json) }
        remember(
            StoredSession(email: json["email"]?.stringValue ?? email, refreshToken: refresh),
            token: token,
            expiresIn: json["expiresIn"]?.doubleValue
        )
    }

    public func signOut() {
        stored = nil
        idToken = nil
        idTokenExpiry = .distantPast
        store.write(nil)
    }

    public func load(_ pageId: String) async throws -> CloudDocument? {
        let url = try documentURL(pageId)
        let (json, status) = try await authorized { token in
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            return request
        }
        if status == 404 { return nil }
        guard status == 200, let updateTime = json["updateTime"]?.stringValue else {
            throw Self.firestoreError(json, status: status)
        }
        let fields = FirestoreCoding.decodeFields(json["fields"])
        return CloudDocument(data: fields["data"] ?? .null, updateTime: updateTime)
    }

    public func save(
        _ pageId: String,
        data: JSONValue,
        precondition: SavePrecondition
    ) async throws -> String {
        var write: [String: JSONValue] = [
            "update": [
                "name": .string(documentName(pageId)),
                "fields": ["data": FirestoreCoding.encode(data)],
            ],
            "updateMask": ["fieldPaths": ["data"]],
            "updateTransforms": [
                ["fieldPath": "updatedAt", "setToServerValue": "REQUEST_TIME"]
            ],
        ]
        switch precondition {
        case .unchangedSince(let version): write["currentDocument"] = ["updateTime": .string(version)]
        case .missing: write["currentDocument"] = ["exists": false]
        case .none: break
        }
        let payload = try JSONEncoder().encode(JSONValue.object(["writes": [.object(write)]]))
        let url = "\(documentsBase()):commit"
        let (json, status) = try await authorized { token in
            guard let target = URL(string: url) else { throw CloudError.server("Bad URL") }
            var request = URLRequest(url: target)
            request.httpMethod = "POST"
            request.httpBody = payload
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            return request
        }
        guard status == 200 else { throw Self.firestoreError(json, status: status) }
        let result = json["writeResults"]?.arrayValue?.first
        guard let version = result?["updateTime"]?.stringValue ?? json["commitTime"]?.stringValue
        else { throw CloudError.server("Save had no version") }
        return version
    }

    // MARK: Tokens

    private func validToken(forceRefresh: Bool) async throws -> String {
        if !forceRefresh, let idToken, idTokenExpiry.timeIntervalSinceNow > 60 {
            return idToken
        }
        guard let stored else { throw CloudError.sessionExpired }
        guard let url = URL(string: "\(config.tokenBase)/v1/token?key=\(config.apiKey)") else {
            throw CloudError.server("Bad URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = URLComponents()
        form.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: stored.refreshToken),
        ]
        request.httpBody = form.percentEncodedQuery?.data(using: .utf8)
        let (json, status) = try await send(request)
        guard status == 200, let token = json["id_token"]?.stringValue else {
            if status >= 500 { throw CloudError.server("Token refresh failed") }
            signOut()
            throw CloudError.sessionExpired
        }
        remember(
            StoredSession(
                email: stored.email,
                refreshToken: json["refresh_token"]?.stringValue ?? stored.refreshToken),
            token: token,
            expiresIn: json["expires_in"]?.doubleValue
        )
        return token
    }

    private func remember(_ session: StoredSession, token: String, expiresIn: Double?) {
        stored = session
        idToken = token
        idTokenExpiry = Date().addingTimeInterval(expiresIn ?? 3600)
        store.write(session)
    }

    /// Runs a request with a token, renewing it once if Firebase turns it down.
    private func authorized(
        _ makeRequest: @Sendable (String) async throws -> URLRequest
    ) async throws -> (JSONValue, Int) {
        let first = try await send(makeRequest(validToken(forceRefresh: false)))
        guard first.1 == 401 else { return first }
        return try await send(makeRequest(validToken(forceRefresh: true)))
    }

    // MARK: Requests

    private func documentsBase() -> String {
        "\(config.firestoreBase)/v1/projects/\(config.projectId)/databases/(default)/documents"
    }

    private func documentName(_ pageId: String) -> String {
        "projects/\(config.projectId)/databases/(default)/documents/\(config.collection)/\(config.syncId)_\(pageId)"
    }

    private func documentURL(_ pageId: String) throws -> URL {
        let path = "\(documentsBase())/\(config.collection)/\(config.syncId)_\(pageId)"
        guard let url = URL(string: path) else { throw CloudError.server("Bad URL") }
        return url
    }

    private func post(_ url: String, json: JSONValue) async throws -> (JSONValue, Int) {
        guard let target = URL(string: url) else { throw CloudError.server("Bad URL") }
        var request = URLRequest(url: target)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(json)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await send(request)
    }

    private func send(_ request: URLRequest) async throws -> (JSONValue, Int) {
        var request = request
        request.timeoutInterval = 15
        do {
            let (data, response) = try await urlSession.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let json = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .null
            return (json, status)
        } catch is URLError {
            throw CloudError.offline
        }
    }

    // MARK: Errors

    private static func authError(_ json: JSONValue) -> CloudError {
        let message = json["error"]?["message"]?.stringValue ?? ""
        if message.hasPrefix("TOO_MANY_ATTEMPTS") { return .tooManyAttempts }
        let badLogin = ["INVALID_LOGIN_CREDENTIALS", "EMAIL_NOT_FOUND", "INVALID_PASSWORD", "INVALID_EMAIL"]
        if badLogin.contains(where: message.hasPrefix) { return .invalidCredentials }
        return .server(message.isEmpty ? "Sign-in failed" : message)
    }

    private static func firestoreError(_ json: JSONValue, status: Int) -> CloudError {
        let code = json["error"]?["status"]?.stringValue ?? json.arrayValue?.first?["error"]?["status"]?.stringValue
        switch code {
        case "FAILED_PRECONDITION", "ABORTED", "ALREADY_EXISTS", "NOT_FOUND": return .conflict
        case "PERMISSION_DENIED": return .denied
        case "UNAUTHENTICATED": return .sessionExpired
        case "UNAVAILABLE", "DEADLINE_EXCEEDED": return .offline
        default: return .server(json["error"]?["message"]?.stringValue ?? "Cloud error \(status)")
        }
    }
}
