import Foundation
import Combine
import SwiftData

@MainActor
protocol RecentSearchPersisting: AnyObject {
    func recentShows() -> [Show]
    func record(show: Show)
    func clearAll()
}

@MainActor
final class RecentSearchStore: ObservableObject, RecentSearchPersisting {
    @Published private(set) var items: [RecentSearchEntity] = []

    private let context: ModelContext
    private let maxEntries: Int

    init(context: ModelContext, maxEntries: Int = 8) {
        self.context = context
        self.maxEntries = maxEntries
        refresh()
    }

    func refresh() {
        let descriptor = FetchDescriptor<RecentSearchEntity>(
            sortBy: [SortDescriptor(\RecentSearchEntity.updatedAt, order: .reverse)]
        )

        do {
            items = try context.fetch(descriptor)
        } catch {
            NSLog("Unable to fetch recent searches: \(error.localizedDescription)")
            items = []
        }
    }

    func recentShows() -> [Show] {
        items.map(mapShow(from:))
    }

    func record(show: Show) {
        if let existing = items.first(where: { $0.showID == show.id }) {
            existing.name = show.name
            existing.posterPath = show.posterPath
            existing.overview = show.overview
            existing.updatedAt = .now
        } else {
            context.insert(
                RecentSearchEntity(
                    showID: show.id,
                    name: show.name,
                    posterPath: show.posterPath,
                    overview: show.overview
                )
            )
        }

        saveAndRefresh()
        pruneOverflowIfNeeded()
    }

    func clearAll() {
        for item in items {
            context.delete(item)
        }
        saveAndRefresh()
    }

    private func pruneOverflowIfNeeded() {
        guard items.count > maxEntries else {
            return
        }

        for overflowItem in items.dropFirst(maxEntries) {
            context.delete(overflowItem)
        }

        saveAndRefresh()
    }

    private func saveAndRefresh() {
        do {
            try context.save()
        } catch {
            NSLog("Unable to save recent searches: \(error.localizedDescription)")
        }

        refresh()
    }

    private func mapShow(from entity: RecentSearchEntity) -> Show {
        Show(
            id: entity.showID,
            name: entity.name,
            posterPath: entity.posterPath,
            overview: entity.overview,
            genres: [],
            status: nil,
            lastAirDate: nil,
            nextEpisodeAirDate: nil,
            airedEpisodeCount: nil
        )
    }
}
