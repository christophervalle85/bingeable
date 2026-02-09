import Foundation
import Combine
import SwiftData

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var items: [TrackedShowEntity] = []

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
        refresh()
    }

    func refresh() {
        let descriptor = FetchDescriptor<TrackedShowEntity>(sortBy: [SortDescriptor(\TrackedShowEntity.updatedAt, order: .reverse)])

        do {
            items = try context.fetch(descriptor)
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
        if let existing = items.first(where: { $0.showID == show.id }) {
            existing.shelf = shelf
            existing.name = show.name
            existing.posterPath = show.posterPath
            existing.overview = show.overview
            existing.updatedAt = .now
        } else {
            let entity = TrackedShowEntity(
                showID: show.id,
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
        for item in items {
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
}
