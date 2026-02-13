import Foundation
import Combine
import SwiftData

@MainActor
final class LibraryStore: ObservableObject {
    static let guestScopeID = "guest"

    @Published private(set) var items: [TrackedShowEntity] = []
    @Published private(set) var activeScopeID: String = guestScopeID

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
        refresh()
    }

    func setActiveScope(_ scopeID: String) {
        let normalized = Self.normalizeScopeID(scopeID)
        guard normalized != activeScopeID else {
            return
        }

        activeScopeID = normalized
        refresh()
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
    }

    func remove(showID: Int) {
        guard let existing = items.first(where: { $0.showID == showID }) else {
            return
        }

        context.delete(existing)
        saveAndRefresh()
    }

    func move(showID: Int, to shelf: LibraryShelf) {
        guard let existing = items.first(where: { $0.showID == showID }) else {
            return
        }

        existing.shelf = shelf
        existing.updatedAt = .now
        saveAndRefresh()
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
}
