import Foundation
import Combine
import SwiftData

@MainActor
protocol RecentSearchPersisting: AnyObject {
    func recentQueries() -> [String]
    func record(query: String)
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

    func recentQueries() -> [String] {
        items.map(\.displayQuery)
    }

    func record(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        let normalized = normalizeQuery(trimmed)
        if let existing = items.first(where: { $0.query == normalized }) {
            existing.displayQuery = trimmed
            existing.updatedAt = .now
        } else {
            context.insert(
                RecentSearchEntity(
                    query: normalized,
                    displayQuery: trimmed
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

    private func normalizeQuery(_ query: String) -> String {
        query
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
