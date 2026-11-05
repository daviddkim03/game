import Foundation
import Observation

public enum SyncIssue: Equatable, Sendable {
    case offline
    case denied
    case sessionExpired
    case failed(String)
}

/// A page as last seen on this device.
public struct CachedDocument: Codable, Equatable, Sendable {
    public var data: JSONValue
    /// The cloud version `data` is based on, or nil if it has never been saved.
    public var updateTime: String?
    public var hasLocalChanges: Bool

    public init(data: JSONValue, updateTime: String?, hasLocalChanges: Bool) {
        self.data = data
        self.updateTime = updateTime
        self.hasLocalChanges = hasLocalChanges
    }
}

public protocol DocumentCache: Sendable {
    func read(_ pageId: String) -> CachedDocument?
    func write(_ document: CachedDocument, pageId: String)
    func clear()
}

/// Keeps pages as files, so the app opens instantly and works with no signal.
public struct FileDocumentCache: DocumentCache {
    private let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    private func url(_ pageId: String) -> URL {
        directory.appendingPathComponent("\(pageId).json")
    }

    public func read(_ pageId: String) -> CachedDocument? {
        guard let data = try? Data(contentsOf: url(pageId)) else { return nil }
        return try? JSONDecoder().decode(CachedDocument.self, from: data)
    }

    public func write(_ document: CachedDocument, pageId: String) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(document) else { return }
        try? data.write(to: url(pageId), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    public func clear() {
        try? FileManager.default.removeItem(at: directory)
    }
}

/// One cloud page held in memory. Edits apply and save locally right away, then
/// go to the cloud one at a time. A save only lands if nobody else has saved
/// since this device last looked; otherwise the edits are redone on top of the
/// newer copy, so a change made on the PC is never overwritten.
@MainActor
@Observable
public final class DocumentStore<Value: CloudValue> {
    public let pageId: String
    public private(set) var value: Value
    /// True once the cloud has answered, or a cached copy exists.
    public private(set) var isLoaded: Bool
    public private(set) var issue: SyncIssue?

    @ObservationIgnored private let backend: CloudBackend
    @ObservationIgnored private let cache: DocumentCache
    @ObservationIgnored private var raw: JSONValue?
    @ObservationIgnored private var updateTime: String?
    @ObservationIgnored private var hasLocalChanges = false
    /// Edits not confirmed yet, kept so they can be redone after a conflict.
    @ObservationIgnored private var unsaved: [(inout Value) -> Void] = []
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    /// Goes up with every edit, to spot a cloud copy read before that edit.
    @ObservationIgnored private var editCount = 0
    /// Runs after `value` changes for any reason.
    @ObservationIgnored public var onChange: (() -> Void)?

    public init(pageId: String, backend: CloudBackend, cache: DocumentCache) {
        self.pageId = pageId
        self.backend = backend
        self.cache = cache
        if let cached = cache.read(pageId), let saved = Value(json: cached.data) {
            value = saved
            raw = cached.data
            updateTime = cached.updateTime
            hasLocalChanges = cached.hasLocalChanges
            isLoaded = true
        } else {
            value = .empty
            isLoaded = false
        }
    }

    /// Picks up the cloud copy, or sends local edits if there are any.
    public func refresh() async {
        guard saveTask == nil else { return }
        if hasLocalChanges {
            await flush()
            return
        }
        let editsBeforeLoading = editCount
        do {
            let document = try await backend.load(pageId)
            issue = nil
            isLoaded = true
            // An edit made during the read is newer than what came back.
            if editCount == editsBeforeLoading { apply(document) }
        } catch {
            record(error)
        }
    }

    /// Applies an edit now and sends it to the cloud.
    public func update(_ change: @escaping (inout Value) -> Void) {
        editCount += 1
        change(&value)
        unsaved.append(change)
        hasLocalChanges = true
        isLoaded = true
        persist()
        onChange?()
        Task { await flush() }
    }

    /// Finishes when everything is saved, or saving fails until later. A save
    /// already underway is waited for, because the app may only have moments
    /// left in the background.
    public func flush() async {
        if let saveTask {
            await saveTask.value
            return
        }
        guard hasLocalChanges else { return }
        let task = Task { await saveChanges() }
        saveTask = task
        await task.value
        saveTask = nil
    }

    private func saveChanges() async {
        var conflicts = 0

        while hasLocalChanges {
            let sending = unsaved.count
            let body = value.toJSON().merged(over: raw, replacing: Value.replacedKeys)
            do {
                let version = try await backend.save(pageId, data: body, precondition: precondition(sending))
                raw = body
                updateTime = version
                unsaved.removeFirst(sending)
                hasLocalChanges = !unsaved.isEmpty
                issue = nil
                persist()
            } catch CloudError.conflict where conflicts < 3 {
                conflicts += 1
                do {
                    try await redoOnNewestCopy()
                } catch {
                    record(error)
                    return
                }
            } catch {
                record(error)
                return
            }
        }
    }

    /// Forgets everything, for signing out.
    public func reset() {
        value = .empty
        raw = nil
        updateTime = nil
        hasLocalChanges = false
        unsaved = []
        isLoaded = false
        issue = nil
    }

    private func precondition(_ sending: Int) -> SavePrecondition {
        // Edits left over from a past launch can't be redone, so like the
        // website they count as the newest copy.
        if sending == 0 { return .none }
        return updateTime.map(SavePrecondition.unchangedSince) ?? .missing
    }

    private func redoOnNewestCopy() async throws {
        let newest = try await backend.load(pageId)
        raw = newest?.data
        updateTime = newest?.updateTime
        var next = newest.flatMap { Value(json: $0.data) } ?? value
        for change in unsaved { change(&next) }
        value = next
        persist()
        onChange?()
    }

    private func apply(_ document: CloudDocument?) {
        guard !hasLocalChanges, let document, document.updateTime != updateTime else { return }
        updateTime = document.updateTime
        raw = document.data
        if let next = Value(json: document.data), next != value {
            value = next
            onChange?()
        }
        persist()
    }

    private func persist() {
        cache.write(
            CachedDocument(
                data: value.toJSON().merged(over: raw, replacing: Value.replacedKeys),
                updateTime: updateTime,
                hasLocalChanges: hasLocalChanges),
            pageId: pageId)
    }

    private func record(_ error: Error) {
        switch error as? CloudError {
        case .offline: issue = .offline
        case .denied: issue = .denied
        case .sessionExpired: issue = .sessionExpired
        case .server(let message): issue = .failed(message)
        default: issue = .failed("Saving failed")
        }
    }
}
