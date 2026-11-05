import Foundation
import Testing

@testable import SystemCore

@MainActor
@Suite struct DocumentStoreTests {
    let week = schedule(block(1, 0, 0, 2, "from the cloud"))

    func store(_ backend: MemoryBackend, cache: DocumentCache = MemoryCache()) -> DocumentStore<Schedule> {
        DocumentStore(pageId: "schedule", backend: backend, cache: cache)
    }

    func settle(_ store: DocumentStore<Schedule>) async {
        // `update` saves on its own task; let it run, then wait for it.
        await Task.yield()
        await store.flush()
        for _ in 0..<20 { await Task.yield() }
        await store.flush()
    }

    @Test func loadsTheCloudCopy() async {
        let backend = MemoryBackend(documents: ["schedule": week.toJSON()])
        let s = store(backend)
        #expect(!s.isLoaded)
        await s.refresh()
        #expect(s.isLoaded)
        #expect(s.value.blocks.map(\.label) == ["from the cloud"])
    }

    @Test func aMissingDocumentStartsEmptyAndGetsCreatedOnSave() async {
        let backend = MemoryBackend()
        let s = store(backend)
        await s.refresh()
        #expect(s.isLoaded)
        s.update { $0.save(block(0, 0, 0, 2, "new")) }
        await settle(s)
        let saved = await backend.documents["schedule"]?.data
        #expect(saved?["blocks"]?.arrayValue?.count == 1)
    }

    @Test func aChangeFromThePCShowsUpOnRefresh() async {
        let backend = MemoryBackend(documents: ["schedule": week.toJSON()])
        let s = store(backend)
        await s.refresh()
        var changes = 0
        s.onChange = { changes += 1 }
        await backend.receive("schedule", data: schedule(block(1, 0, 0, 2, "edited on the PC")).toJSON())
        await s.refresh()
        #expect(s.value.blocks.map(\.label) == ["edited on the PC"])
        #expect(changes == 1)
        await s.refresh()
        #expect(changes == 1)
    }

    @Test func editsApplyInstantlyAndReachTheCloud() async {
        let backend = MemoryBackend(documents: ["schedule": week.toJSON()])
        let s = store(backend)
        await s.refresh()
        s.update { $0.delete(1) }
        #expect(s.value.blocks.isEmpty)
        await settle(s)
        let saved = await backend.documents["schedule"]?.data
        #expect(saved?["blocks"]?.arrayValue?.isEmpty == true)
    }

    @Test func aSimultaneousPCEditIsKeptNotOverwritten() async {
        let backend = MemoryBackend(documents: ["schedule": week.toJSON()])
        let s = store(backend)
        await s.refresh()
        // The PC saves after the phone last looked, then the phone edits.
        let pc = schedule(block(1, 0, 0, 2, "from the cloud"), block(2, 1, 0, 2, "added on the PC"))
        await backend.receive("schedule", data: pc.toJSON())
        s.update { $0.save(block(0, 2, 0, 2, "added on the phone")) }
        await settle(s)
        let saved = await Schedule(json: backend.documents["schedule"]!.data)!
        #expect(Set(saved.blocks.map(\.label)) == ["from the cloud", "added on the PC", "added on the phone"])
        #expect(s.value == saved)
    }

    @Test func fieldsTheAppDoesNotKnowSurviveAnEdit() async {
        var cloud = week.toJSON().objectValue!
        cloud["webOnlySetting"] = "keep me"
        let blockWithExtra: JSONValue = [
            "id": 1, "day": 0, "start": 0, "end": 2, "label": "x", "color": "#111111", "note": "keep me too",
        ]
        cloud["blocks"] = [blockWithExtra]
        let backend = MemoryBackend(documents: ["schedule": .object(cloud)])
        let s = store(backend)
        await s.refresh()
        s.update { $0.selColor = "#222222" }
        await settle(s)
        let saved = await backend.documents["schedule"]?.data
        #expect(saved?["webOnlySetting"] == "keep me")
        #expect(saved?["blocks"]?.arrayValue?.first?["note"] == "keep me too")
        #expect(saved?["selColor"] == "#222222")
    }

    @Test func offlineEditsStayLocalThenSendWhenBack() async {
        let backend = MemoryBackend(documents: ["schedule": week.toJSON()])
        let s = store(backend)
        await s.refresh()
        await backend.setOffline(true)
        s.update { $0.save(block(0, 2, 0, 2, "offline edit")) }
        await settle(s)
        #expect(s.issue == .offline)
        #expect(s.value.blocks.count == 2)
        #expect(await backend.saves["schedule"] == nil)

        await backend.setOffline(false)
        await s.refresh()
        #expect(s.issue == nil)
        #expect(await backend.saves["schedule"] == 1)
    }

    @Test func aRestartWithUnsavedEditsStillSendsThem() async {
        let backend = MemoryBackend(documents: ["schedule": week.toJSON()])
        let cache = MemoryCache()
        let first = store(backend, cache: cache)
        await first.refresh()
        await backend.setOffline(true)
        first.update { $0.save(block(0, 2, 0, 2, "before the restart")) }
        await settle(first)

        await backend.setOffline(false)
        let second = store(backend, cache: cache)
        #expect(second.value.blocks.count == 2)
        await second.refresh()
        let saved = await backend.documents["schedule"]?.data
        #expect(saved?["blocks"]?.arrayValue?.count == 2)
    }

    @Test func aCachedCopyOpensInstantlyWithNoNetwork() async {
        let backend = MemoryBackend(documents: ["schedule": week.toJSON()])
        let cache = MemoryCache()
        let first = store(backend, cache: cache)
        await first.refresh()
        await backend.setOffline(true)
        let second = store(backend, cache: cache)
        #expect(second.isLoaded)
        #expect(second.value.blocks.map(\.label) == ["from the cloud"])
        await second.refresh()
        #expect(second.value.blocks.map(\.label) == ["from the cloud"])
        #expect(second.issue == .offline)
    }

    @Test func editsWhileASaveIsRunningAreNotLost() async {
        let backend = MemoryBackend(documents: ["schedule": week.toJSON()])
        let s = store(backend)
        await s.refresh()
        for index in 0..<5 {
            s.update { $0.save(block(0, 2, index * 2, index * 2 + 2, "edit \(index)")) }
        }
        await settle(s)
        let saved = await Schedule(json: backend.documents["schedule"]!.data)!
        #expect(saved.blocks.count == 6)
    }

    @Test func aSlowPollCannotOverwriteAnEditMadeDuringIt() async {
        let backend = MemoryBackend(documents: ["schedule": week.toJSON()])
        let s = store(backend)
        await s.refresh()
        await backend.setLoadDelay(.milliseconds(100))

        // A background poll has read the old copy; the edit lands and saves
        // before that old copy arrives.
        async let poll: Void = s.refresh()
        try? await Task.sleep(for: .milliseconds(20))
        s.update { $0.save(block(0, 2, 0, 2, "tapped during the poll")) }
        await s.flush()
        await poll

        #expect(s.value.blocks.map(\.label).contains("tapped during the poll"))
        await backend.setLoadDelay(nil)
        await s.refresh()
        #expect(s.value.blocks.map(\.label).contains("tapped during the poll"))
    }

    @Test func flushWaitsForASaveAlreadyUnderway() async {
        let backend = MemoryBackend(documents: ["schedule": week.toJSON()])
        await backend.setSaveDelay(.milliseconds(100))
        let s = store(backend)
        await s.refresh()
        s.update { $0.delete(1) }
        for _ in 0..<20 { await Task.yield() }
        // The app could be suspended the moment this returns.
        await s.flush()
        #expect(await backend.saves["schedule"] == 1)
    }

    @Test func aFileCacheSurvivesBetweenLaunches() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = FileDocumentCache(directory: directory)
        let document = CachedDocument(data: ["a": 1], updateTime: "v1", hasLocalChanges: true)
        cache.write(document, pageId: "x")
        #expect(cache.read("x") == document)
        cache.clear()
        #expect(cache.read("x") == nil)
    }

    @Test func resetForgetsEverything() async {
        let backend = MemoryBackend(documents: ["schedule": week.toJSON()])
        let s = store(backend)
        await s.refresh()
        s.reset()
        #expect(s.value == .empty)
        #expect(!s.isLoaded)
    }
}
