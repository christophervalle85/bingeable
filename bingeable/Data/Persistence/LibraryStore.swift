import Foundation
import Combine
import SwiftData

@MainActor
final class LibraryStore: ObservableObject {
    static let guestScopeID = "guest"

    @Published private(set) var items: [TrackedShowEntity] = []
    @Published private(set) var activeScopeID: String = guestScopeID

    private let context: ModelContext
    private var syncService: (any LibrarySyncServicing)?
    private var scopeSyncTask: Task<Void, Never>?

    init(context: ModelContext) {
        self.context = context
        refresh()
    }

    deinit {
        scopeSyncTask?.cancel()
    }

    func configure(syncService: any LibrarySyncServicing) {
        self.syncService = syncService
        startScopeSynchronization(force: true)
    }

    func setActiveScope(_ scopeID: String) {
        let normalized = Self.normalizeScopeID(scopeID)
        guard normalized != activeScopeID else {
            return
        }

        activeScopeID = normalized
        refresh()
        startScopeSynchronization(force: true)
    }

    func refresh() {
        let scopeID = activeScopeID
        let descriptor: FetchDescriptor<TrackedShowEntity>
        if scopeID == Self.guestScopeID {
            descriptor = FetchDescriptor<TrackedShowEntity>(
                predicate: #Predicate<TrackedShowEntity> { entity in
                    entity.scopeID == scopeID || entity.scopeID == ""
                },
                sortBy: [SortDescriptor(\TrackedShowEntity.updatedAt, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<TrackedShowEntity>(
                predicate: #Predicate<TrackedShowEntity> { entity in
                    entity.scopeID == scopeID
                },
                sortBy: [SortDescriptor(\TrackedShowEntity.updatedAt, order: .reverse)]
            )
        }

        do {
            items = try context.fetch(descriptor)
            migrateLoadedItemsIfNeeded()
        } catch {
            NSLog("Unable to fetch tracked shows: \(error.localizedDescription)")
            items = []
        }
    }

    func shelf(for showID: Int) -> LibraryShelf? {
        items.first(where: { $0.showID == showID })?.shelf
    }

    func allTrackedShows() -> [TrackedShow] {
        items.map(mapTrackedShow(from:))
    }

    func trackedShows(in shelf: LibraryShelf) -> [TrackedShow] {
        items
            .filter { $0.shelf == shelf }
            .map(mapTrackedShow(from:))
    }

    func upsert(show: Show, shelf: LibraryShelf) {
        let scopeID = activeScopeID

        if let existing = items.first(where: { $0.showID == show.id }) {
            existing.scopeID = scopeID
            existing.scopedShowID = TrackedShowEntity.makeScopedShowID(scopeID: scopeID, showID: show.id)
            existing.shelf = shelf
            existing.name = show.name
            existing.posterPath = show.posterPath
            existing.overview = show.overview
            existing.updatedAt = .now
        } else {
            let entity = TrackedShowEntity(
                showID: show.id,
                scopeID: scopeID,
                shelf: shelf,
                name: show.name,
                posterPath: show.posterPath,
                overview: show.overview
            )
            context.insert(entity)
        }

        saveAndRefresh()

        if shouldSync(scopeID: scopeID), let tracked = trackedShow(for: show.id) {
            enqueueRemoteUpsert(tracked, scopeID: scopeID)
        }
    }

    func remove(showID: Int) {
        let scopeID = activeScopeID

        guard let existing = items.first(where: { $0.showID == showID }) else {
            return
        }

        context.delete(existing)
        saveAndRefresh()

        if shouldSync(scopeID: scopeID) {
            enqueueRemoteRemoval(showID: showID, scopeID: scopeID)
        }
    }

    func move(showID: Int, to shelf: LibraryShelf) {
        let scopeID = activeScopeID

        guard let existing = items.first(where: { $0.showID == showID }) else {
            return
        }

        existing.shelf = shelf
        existing.updatedAt = .now
        saveAndRefresh()

        if shouldSync(scopeID: scopeID), let tracked = trackedShow(for: showID) {
            enqueueRemoteUpsert(tracked, scopeID: scopeID)
        }
    }

    func clearAll() {
        let descriptor = FetchDescriptor<TrackedShowEntity>()
        let allItems = (try? context.fetch(descriptor)) ?? []

        for item in allItems {
            context.delete(item)
        }

        saveAndRefresh()
    }

    private func mapTrackedShow(from entity: TrackedShowEntity) -> TrackedShow {
        TrackedShow(
            id: entity.showID,
            shelf: entity.shelf,
            addedAt: entity.addedAt,
            updatedAt: entity.updatedAt,
            name: entity.name,
            posterPath: entity.posterPath,
            overview: entity.overview
        )
    }

    private func saveAndRefresh() {
        do {
            try context.save()
        } catch {
            NSLog("Unable to save library changes: \(error.localizedDescription)")
        }

        refresh()
    }

    private func migrateLoadedItemsIfNeeded() {
        var didMutate = false

        for item in items {
            let normalizedScopeID = Self.normalizeScopeID(item.scopeID)
            if normalizedScopeID != item.scopeID {
                item.scopeID = normalizedScopeID
                didMutate = true
            }

            let expectedScopedID = TrackedShowEntity.makeScopedShowID(scopeID: normalizedScopeID, showID: item.showID)
            if item.scopedShowID != expectedScopedID {
                item.scopedShowID = expectedScopedID
                didMutate = true
            }
        }

        guard didMutate else {
            return
        }

        do {
            try context.save()
            items.sort { $0.updatedAt > $1.updatedAt }
        } catch {
            NSLog("Unable to migrate scoped library items: \(error.localizedDescription)")
        }
    }

    private static func normalizeScopeID(_ scopeID: String) -> String {
        let trimmed = scopeID.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "signed_out" {
            return guestScopeID
        }
        return trimmed
    }

    private func shouldSync(scopeID: String) -> Bool {
        scopeID != Self.guestScopeID
    }

    private func trackedShow(for showID: Int) -> TrackedShow? {
        guard let entity = items.first(where: { $0.showID == showID }) else {
            return nil
        }

        return mapTrackedShow(from: entity)
    }

    private func enqueueRemoteUpsert(_ trackedShow: TrackedShow, scopeID: String) {
        guard let syncService else {
            return
        }

        Task {
            do {
                try await syncService.upsert(trackedShow, for: scopeID)
            } catch {
                NSLog("Unable to sync upsert for show \(trackedShow.id): \(error.localizedDescription)")
            }
        }
    }

    private func enqueueRemoteRemoval(showID: Int, scopeID: String) {
        guard let syncService else {
            return
        }

        Task {
            do {
                try await syncService.remove(showID: showID, for: scopeID)
            } catch {
                NSLog("Unable to sync removal for show \(showID): \(error.localizedDescription)")
            }
        }
    }

    private func startScopeSynchronization(force: Bool = false) {
        guard shouldSync(scopeID: activeScopeID), let syncService else {
            scopeSyncTask?.cancel()
            scopeSyncTask = nil
            return
        }

        if !force, scopeSyncTask != nil {
            return
        }

        let scopeID = activeScopeID
        scopeSyncTask?.cancel()
        scopeSyncTask = Task { [weak self] in
            await self?.synchronizeScope(scopeID: scopeID, using: syncService)
        }
    }

    private func synchronizeScope(scopeID: String, using syncService: any LibrarySyncServicing) async {
        guard scopeID == activeScopeID else {
            return
        }

        do {
            let remoteShows = try await syncService.fetchLibrary(for: scopeID)

            if Task.isCancelled || scopeID != activeScopeID {
                return
            }

            let localShows = allTrackedShows()
            let localByID = Dictionary(uniqueKeysWithValues: localShows.map { ($0.id, $0) })
            let remoteByID = Dictionary(uniqueKeysWithValues: remoteShows.map { ($0.id, $0) })
            let allIDs = Set(localByID.keys).union(remoteByID.keys)

            var didMutateLocal = false
            var localShowsToPush: [TrackedShow] = []

            for showID in allIDs {
                let local = localByID[showID]
                let remote = remoteByID[showID]

                switch (local, remote) {
                case let (local?, nil):
                    localShowsToPush.append(local)
                case let (nil, remote?):
                    applyRemoteTrackedShow(remote, scopeID: scopeID)
                    didMutateLocal = true
                case let (local?, remote?):
                    if remote.updatedAt > local.updatedAt {
                        applyRemoteTrackedShow(remote, scopeID: scopeID)
                        didMutateLocal = true
                    } else if local.updatedAt >= remote.updatedAt {
                        localShowsToPush.append(local)
                    }
                case (nil, nil):
                    break
                }
            }

            if didMutateLocal {
                saveAndRefresh()
            }

            for localShow in localShowsToPush {
                if Task.isCancelled || scopeID != activeScopeID {
                    return
                }

                do {
                    try await syncService.upsert(localShow, for: scopeID)
                } catch {
                    NSLog("Unable to push local show \(localShow.id) to cloud: \(error.localizedDescription)")
                }
            }
        } catch {
            NSLog("Unable to fetch cloud library for scope \(scopeID): \(error.localizedDescription)")
        }
    }

    private func applyRemoteTrackedShow(_ trackedShow: TrackedShow, scopeID: String) {
        if let existing = items.first(where: { $0.showID == trackedShow.id }) {
            existing.scopeID = scopeID
            existing.scopedShowID = TrackedShowEntity.makeScopedShowID(scopeID: scopeID, showID: trackedShow.id)
            existing.shelf = trackedShow.shelf
            existing.name = trackedShow.name
            existing.posterPath = trackedShow.posterPath
            existing.overview = trackedShow.overview
            existing.addedAt = trackedShow.addedAt
            existing.updatedAt = trackedShow.updatedAt
        } else {
            let entity = TrackedShowEntity(
                showID: trackedShow.id,
                scopeID: scopeID,
                shelf: trackedShow.shelf,
                name: trackedShow.name,
                posterPath: trackedShow.posterPath,
                overview: trackedShow.overview,
                addedAt: trackedShow.addedAt,
                updatedAt: trackedShow.updatedAt
            )
            context.insert(entity)
        }
    }
}
