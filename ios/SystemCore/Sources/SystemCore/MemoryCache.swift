import Foundation

/// A `DocumentCache` that lasts only as long as the process.
public final class MemoryCache: DocumentCache, @unchecked Sendable {
    private let lock = NSLock()
    private var documents: [String: CachedDocument] = [:]

    public init() {}

    public func read(_ pageId: String) -> CachedDocument? {
        lock.withLock { documents[pageId] }
    }

    public func write(_ document: CachedDocument, pageId: String) {
        lock.withLock { documents[pageId] = document }
    }

    public func clear() {
        lock.withLock { documents = [:] }
    }
}
