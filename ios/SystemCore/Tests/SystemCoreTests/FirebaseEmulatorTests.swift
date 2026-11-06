import Foundation
import Testing

@testable import SystemCore

/// Runs the real REST client against the Firebase emulators, which use the same
/// wire format and security rules as production. See `ios/emulator/run.sh`.
private let isEnabled = ProcessInfo.processInfo.environment["FIREBASE_EMULATOR"] != nil

private final class InMemorySessions: SessionStore, @unchecked Sendable {
    private let lock = NSLock()
    private var session: StoredSession?

    init(_ session: StoredSession? = nil) {
        self.session = session
    }

    func read() -> StoredSession? { lock.withLock { session } }
    func write(_ session: StoredSession?) { lock.withLock { self.session = session } }
}

private let config = CloudConfig.emulator(projectId: "demo-system", authPort: 9099, firestorePort: 8181)
private let ownerEmail = "owner@example.com"
private let strangerEmail = "stranger@example.com"
private let testPassword = "emulator-only"

private func signedIn(_ email: String = ownerEmail) async throws -> (FirebaseBackend, InMemorySessions) {
    let sessions = InMemorySessions()
    let backend = FirebaseBackend(config: config, store: sessions)
    try await backend.signIn(email: email, password: testPassword)
    return (backend, sessions)
}

private func uniquePage() -> String {
    "test_\(UUID().uuidString.prefix(8))"
}

@Suite(.enabled(if: isEnabled), .serialized)
struct FirebaseEmulatorTests {
    @Test func aWrongPasswordIsRejected() async {
        let backend = FirebaseBackend(config: config, store: InMemorySessions())
        await #expect(throws: CloudError.invalidCredentials) {
            try await backend.signIn(email: ownerEmail, password: "wrong-password")
        }
        await #expect(throws: CloudError.invalidCredentials) {
            try await backend.signIn(email: "nobody@example.com", password: "wrong-password")
        }
    }

    @Test func signingInKeepsARefreshTokenButNeverThePassword() async throws {
        let (backend, sessions) = try await signedIn()
        #expect(await backend.currentEmail() == ownerEmail)
        let session = try #require(sessions.read())
        #expect(!session.refreshToken.isEmpty)
        #expect(!session.refreshToken.contains(testPassword))
    }

    @Test func aMissingPageIsNil() async throws {
        let (backend, _) = try await signedIn()
        #expect(try await backend.load(uniquePage()) == nil)
    }

    @Test func everyKindOfValueSurvivesASaveAndLoad() async throws {
        let (backend, _) = try await signedIn()
        let page = uniquePage()
        let data: JSONValue = [
            "whole": 700, "fraction": 0.25, "negative": -12.5, "text": "café \"quoted\"", "flag": false,
            "nothing": nil, "list": [1, "two", ["three": 3]], "emptyList": [], "emptyMap": [:],
        ]
        let version = try await backend.save(page, data: data, precondition: .missing)
        let loaded = try #require(try await backend.load(page))
        #expect(loaded.data == data)
        #expect(loaded.updateTime == version)
    }

    @Test func aSaveBasedOnAnOldVersionConflicts() async throws {
        let (backend, _) = try await signedIn()
        let page = uniquePage()
        let first = try await backend.save(page, data: ["n": 1], precondition: .missing)
        let second = try await backend.save(page, data: ["n": 2], precondition: .unchangedSince(first))
        #expect(second != first)
        await #expect(throws: CloudError.conflict) {
            try await backend.save(page, data: ["n": 3], precondition: .unchangedSince(first))
        }
        await #expect(throws: CloudError.conflict) {
            try await backend.save(page, data: ["n": 4], precondition: .missing)
        }
        #expect(try await backend.load(page)?.data == ["n": 2])
    }

    @Test func savingReplacesDataInsteadOfMergingOldKeysBackIn() async throws {
        let (backend, _) = try await signedIn()
        let page = uniquePage()
        _ = try await backend.save(page, data: ["a": 1, "map": ["x": 1, "y": 2]], precondition: .none)
        _ = try await backend.save(page, data: ["map": ["x": 1]], precondition: .none)
        #expect(try await backend.load(page)?.data == ["map": ["x": 1]])
    }

    @Test func aSavedSessionWorksAfterARestart() async throws {
        let (first, sessions) = try await signedIn()
        let page = uniquePage()
        _ = try await first.save(page, data: ["n": 1], precondition: .none)

        // A new launch has only the stored refresh token.
        let second = FirebaseBackend(config: config, store: sessions)
        #expect(await second.currentEmail() == ownerEmail)
        #expect(try await second.load(page)?.data == ["n": 1])
    }

    @Test func aRevokedSessionAsksToSignInAgain() async throws {
        let sessions = InMemorySessions(StoredSession(email: ownerEmail, refreshToken: "not-a-real-token"))
        let backend = FirebaseBackend(config: config, store: sessions)
        await #expect(throws: CloudError.sessionExpired) {
            _ = try await backend.load(uniquePage())
        }
        #expect(await backend.currentEmail() == nil)
        #expect(sessions.read() == nil)
    }

    @Test func noSessionCannotReachAnything() async {
        let backend = FirebaseBackend(config: config, store: InMemorySessions())
        await #expect(throws: CloudError.sessionExpired) {
            _ = try await backend.load(uniquePage())
        }
    }

    @Test func theSecurityRulesBlockEveryoneButTheOwner() async throws {
        let (stranger, _) = try await signedIn(strangerEmail)
        await #expect(throws: CloudError.denied) {
            _ = try await stranger.load(uniquePage())
        }
        await #expect(throws: CloudError.denied) {
            _ = try await stranger.save(uniquePage(), data: ["n": 1], precondition: .none)
        }
    }

    @Test func thePhoneDocumentIsAllowedByTheRules() async throws {
        let (backend, _) = try await signedIn()
        _ = try await backend.save(PhonePrefs.pageId, data: PhonePrefs.empty.toJSON(), precondition: .none)
        #expect(try await backend.load(PhonePrefs.pageId) != nil)
    }

    /// `ios/emulator/web-sync.mjs` plays the website on either side of this.
    @Test func exchangesTheWebsitesDocumentsBothWays() async throws {
        let (backend, _) = try await signedIn()
        let cloud = try #require(try await backend.load("schedule"), "Run through ios/emulator/run.sh")
        let week = try #require(Schedule(json: cloud.data))
        #expect(week.blocks.map(\.label) == ["saved by the website"])
        #expect(cloud.data["webOnlySetting"] == "keep me")

        let store = await DocumentStore<Schedule>(pageId: "schedule", backend: backend, cache: MemoryCache())
        await store.refresh()
        await MainActor.run {
            store.update {
                $0.save(Block(id: 0, day: 2, start: 4, end: 8, label: "saved by the phone", color: "#378ADD"))
            }
        }
        await Task.yield()
        for _ in 0..<50 {
            try await Task.sleep(for: .milliseconds(20))
            if try await backend.load("schedule")?.data["blocks"]?.arrayValue?.count == 2 { break }
        }
        let after = try #require(try await backend.load("schedule"))
        #expect(after.data["blocks"]?.arrayValue?.count == 2)
        #expect(after.data["webOnlySetting"] == "keep me")
    }
}
