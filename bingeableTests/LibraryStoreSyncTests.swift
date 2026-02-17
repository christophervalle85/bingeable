import Foundation
import SwiftData
import Testing
@testable import bingeable

struct LibraryStoreSyncTests {
    @Test("Signed-in mutations write through to remote sync")
    @MainActor
    func signedInMutationsWriteThrough() async throws {
        let harness = try makeStoreHarness()
        let store = harness.store
        let sync = MockLibrarySyncService()
        let userID = "uid-write-through"

        store.configure(syncService: sync)
        store.setActiveScope(userID)

        let show = makeShow(id: 101, name: "Write Through")
        store.upsert(show: show, shelf: .waiting)
        store.move(showID: show.id, to: .watching)
        store.remove(showID: show.id)

        let synced = await waitUntil {
            let snapshot = sync.snapshot()
            let upsertCount = snapshot.upsertCalls.filter {
                $0.userID == userID && $0.showID == show.id
            }.count
            let removed = snapshot.removeCalls.contains {
                $0.userID == userID && $0.showID == show.id
            }
            return upsertCount >= 2 && removed
        }

        #expect(synced)
        #expect(sync.snapshot().fetchCalls.contains(userID))
    }

    @Test("Guest scope never issues remote sync calls")
    @MainActor
    func guestScopeStaysLocalOnly() async throws {
        let harness = try makeStoreHarness()
        let store = harness.store
        let sync = MockLibrarySyncService()
        let show = makeShow(id: 102, name: "Guest Only")

        store.configure(syncService: sync)
        store.setActiveScope(LibraryStore.guestScopeID)
        store.upsert(show: show, shelf: .waiting)
        store.move(showID: show.id, to: .finished)
        store.remove(showID: show.id)

        try await Task.sleep(nanoseconds: 150_000_000)

        let snapshot = sync.snapshot()
        #expect(snapshot.fetchCalls.isEmpty)
        #expect(snapshot.upsertCalls.isEmpty)
        #expect(snapshot.removeCalls.isEmpty)
    }

    @Test("Scope sync pulls remote record when remote is newer")
    @MainActor
    func scopeSyncPrefersRemoteWhenNewer() async throws {
        let harness = try makeStoreHarness()
        let store = harness.store
        let sync = MockLibrarySyncService()
        let userID = "uid-remote-newer"
        let show = makeShow(id: 103, name: "Local Old")

        store.setActiveScope(userID)
        store.upsert(show: show, shelf: .waiting)

        guard let local = store.allTrackedShows().first(where: { $0.id == show.id }) else {
            Issue.record("Expected local tracked show for setup.")
            return
        }

        let remote = TrackedShow(
            id: show.id,
            shelf: .finished,
            addedAt: local.addedAt,
            updatedAt: local.updatedAt.addingTimeInterval(120),
            name: "Remote New",
            posterPath: "/remote.jpg",
            overview: "Remote overview"
        )
        sync.seedRemote([remote], for: userID)

        store.configure(syncService: sync)

        let applied = await waitUntil {
            guard let merged = store.allTrackedShows().first(where: { $0.id == show.id }) else {
                return false
            }
            return merged.shelf == .finished && merged.name == "Remote New"
        }

        #expect(applied)
    }

    @Test("Scope sync pushes local record when local is newer")
    @MainActor
    func scopeSyncPushesLocalWhenNewer() async throws {
        let harness = try makeStoreHarness()
        let store = harness.store
        let sync = MockLibrarySyncService()
        let userID = "uid-local-newer"
        let show = makeShow(id: 104, name: "Local New")

        store.setActiveScope(userID)
        store.upsert(show: show, shelf: .watching)

        guard let local = store.allTrackedShows().first(where: { $0.id == show.id }) else {
            Issue.record("Expected local tracked show for setup.")
            return
        }

        let remote = TrackedShow(
            id: show.id,
            shelf: .waiting,
            addedAt: local.addedAt,
            updatedAt: local.updatedAt.addingTimeInterval(-120),
            name: "Remote Old",
            posterPath: nil,
            overview: "Older data"
        )
        sync.seedRemote([remote], for: userID)

        store.configure(syncService: sync)

        let pushed = await waitUntil {
            sync.snapshot().upsertCalls.contains {
                $0.userID == userID && $0.showID == show.id && $0.shelf == .watching
            }
        }

        #expect(pushed)
        #expect(store.shelf(for: show.id) == .watching)
    }

    @MainActor
    private func makeStoreHarness() throws -> StoreHarness {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: TrackedShowEntity.self, configurations: configuration)
        let store = LibraryStore(context: container.mainContext)
        return StoreHarness(container: container, store: store)
    }

    private func makeShow(id: Int, name: String) -> Show {
        Show(
            id: id,
            name: name,
            posterPath: nil,
            overview: "Overview for \(name)",
            genres: [],
            status: nil,
            lastAirDate: nil,
            nextEpisodeAirDate: nil,
            airedEpisodeCount: nil
        )
    }

    private func waitUntil(
        timeoutNanoseconds: UInt64 = 1_200_000_000,
        pollNanoseconds: UInt64 = 20_000_000,
        condition: @escaping () async -> Bool
    ) async -> Bool {
        let start = DispatchTime.now().uptimeNanoseconds
        let deadline = start + timeoutNanoseconds

        while DispatchTime.now().uptimeNanoseconds < deadline {
            if await condition() {
                return true
            }
            try? await Task.sleep(nanoseconds: pollNanoseconds)
        }

        return await condition()
    }
}

private struct StoreHarness {
    let container: ModelContainer
    let store: LibraryStore
}

@MainActor
private final class MockLibrarySyncService: LibrarySyncServicing {
    struct UpsertCall: Equatable {
        let userID: String
        let showID: Int
        let shelf: LibraryShelf
    }

    struct RemoveCall: Equatable {
        let userID: String
        let showID: Int
    }

    struct Snapshot {
        let fetchCalls: [String]
        let upsertCalls: [UpsertCall]
        let removeCalls: [RemoveCall]
    }

    private var remoteByUser: [String: [Int: TrackedShow]] = [:]
    private var fetchCalls: [String] = []
    private var upsertCalls: [UpsertCall] = []
    private var removeCalls: [RemoveCall] = []

    func seedRemote(_ shows: [TrackedShow], for userID: String) {
        remoteByUser[userID] = Dictionary(uniqueKeysWithValues: shows.map { ($0.id, $0) })
    }

    func snapshot() -> Snapshot {
        return Snapshot(
            fetchCalls: fetchCalls,
            upsertCalls: upsertCalls,
            removeCalls: removeCalls
        )
    }

    func fetchLibrary(for userID: String) async throws -> [TrackedShow] {
        fetchCalls.append(userID)
        return Array((remoteByUser[userID] ?? [:]).values).sorted { $0.updatedAt > $1.updatedAt }
    }

    func upsert(_ trackedShow: TrackedShow, for userID: String) async throws {
        upsertCalls.append(
            UpsertCall(userID: userID, showID: trackedShow.id, shelf: trackedShow.shelf)
        )
        var scoped = remoteByUser[userID] ?? [:]
        scoped[trackedShow.id] = trackedShow
        remoteByUser[userID] = scoped
    }

    func remove(showID: Int, for userID: String) async throws {
        removeCalls.append(RemoveCall(userID: userID, showID: showID))
        remoteByUser[userID]?[showID] = nil
    }
}
