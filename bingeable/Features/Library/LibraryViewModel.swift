import Foundation
import Combine

@MainActor
final class LibraryViewModel: ObservableObject {
    enum LibraryShelfFilter: String, CaseIterable, Identifiable {
        case all
        case waiting
        case watching
        case finished

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all:
                return "All"
            case .waiting:
                return "Waiting"
            case .watching:
                return "Watching"
            case .finished:
                return "Finished"
            }
        }

        var systemImage: String {
            switch self {
            case .all:
                return "square.grid.2x2"
            case .waiting:
                return "clock"
            case .watching:
                return "play.circle"
            case .finished:
                return "checkmark.circle"
            }
        }

        func includes(_ shelf: LibraryShelf) -> Bool {
            switch self {
            case .all:
                return true
            case .waiting:
                return shelf == .waiting
            case .watching:
                return shelf == .watching
            case .finished:
                return shelf == .finished
            }
        }
    }

    enum LibraryStatusBucket: String, CaseIterable, Identifiable {
        case readyNow
        case notYet
        case unknown

        var id: String { rawValue }

        var title: String {
            switch self {
            case .readyNow:
                return "Ready Now"
            case .notYet:
                return "Up Next"
            case .unknown:
                return "Unknown"
            }
        }

        var subtitle: String {
            switch self {
            case .readyNow:
                return "Shows that are ready to binge"
            case .notYet:
                return "Still airing or waiting on episodes"
            case .unknown:
                return "Need more metadata to classify"
            }
        }

        var systemImage: String {
            switch self {
            case .readyNow:
                return "sparkles.tv"
            case .notYet:
                return "calendar.badge.clock"
            case .unknown:
                return "questionmark.circle"
            }
        }
    }

    struct LibraryDisplayItem: Identifiable, Hashable {
        let tracked: TrackedShow
        let hydratedShow: Show?
        let bucket: LibraryStatusBucket

        var id: Int { tracked.id }
        var shelf: LibraryShelf { tracked.shelf }

        var displayName: String {
            hydratedShow?.name ?? tracked.name
        }

        var overview: String {
            let source = hydratedShow?.overview ?? tracked.overview
            return source.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var statusLabel: String {
            if let status = hydratedShow?.status {
                return status.displayName
            }

            return shelf.title
        }

        var seedShow: Show {
            hydratedShow ?? tracked.asSeedShow
        }

        var nextEpisodeAirDate: Date? {
            hydratedShow?.nextEpisodeAirDate
        }
    }

    struct LibrarySection: Identifiable, Hashable {
        let bucket: LibraryStatusBucket
        let items: [LibraryDisplayItem]

        var id: String { bucket.rawValue }
        var title: String { bucket.title }
        var subtitle: String { bucket.subtitle }
        var systemImage: String { bucket.systemImage }
    }

    struct LibrarySummary: Equatable {
        var totalCount: Int = 0
        var readyCount: Int = 0
        var watchingCount: Int = 0
        var waitingCount: Int = 0
    }

    @Published var searchQuery: String = "" {
        didSet {
            guard oldValue != searchQuery else { return }
            rebuildSections()
        }
    }
    @Published var shelfFilter: LibraryShelfFilter = .all {
        didSet {
            guard oldValue != shelfFilter else { return }
            rebuildSections()
        }
    }
    @Published private(set) var sections: [LibrarySection] = []
    @Published private(set) var summary = LibrarySummary()
    @Published private(set) var isHydrating = false
    @Published private(set) var hydrationErrorMessage: String?

    private var trackedShows: [TrackedShow] = []
    private var hydratedShowsByID: [Int: Show] = [:]
    private var failedHydrationIDs: Set<Int> = []
    private var hydrationTask: Task<Void, Never>?
    
    init() {}

    deinit {
        hydrationTask?.cancel()
    }

    func load(tracked: [TrackedShow], repository: any ShowRepository) {
        trackedShows = tracked.sorted { lhs, rhs in
            lhs.updatedAt > rhs.updatedAt
        }

        rebuildSections()
        startHydration(using: repository)
    }

    func move(showID: Int, to shelf: LibraryShelf, using store: LibraryStore, repository: any ShowRepository) {
        store.move(showID: showID, to: shelf)
        load(tracked: store.allTrackedShows(), repository: repository)
    }

    func remove(showID: Int, using store: LibraryStore, repository: any ShowRepository) {
        store.remove(showID: showID)
        hydratedShowsByID[showID] = nil
        failedHydrationIDs.remove(showID)
        load(tracked: store.allTrackedShows(), repository: repository)
    }

    func waitForHydrationForTesting() async {
        await hydrationTask?.value
    }

    private func startHydration(using repository: any ShowRepository) {
        hydrationTask?.cancel()
        hydrationTask = nil
        hydrationErrorMessage = nil

        let hydrationIDs = Array(trackedShows.prefix(24).map(\.id)).filter {
            hydratedShowsByID[$0] == nil && !failedHydrationIDs.contains($0)
        }

        guard !hydrationIDs.isEmpty else {
            isHydrating = false
            return
        }

        isHydrating = true

        hydrationTask = Task { [weak self] in
            await self?.hydrate(ids: hydrationIDs, repository: repository)
        }
    }

    private func hydrate(ids: [Int], repository: any ShowRepository) async {
        var failureCount = 0

        for chunk in ids.chunked(into: 4) {
            if Task.isCancelled {
                return
            }

            await withTaskGroup(of: (Int, Show?).self) { group in
                for showID in chunk {
                    group.addTask {
                        do {
                            let detail = try await repository.showDetail(showID: showID)
                            return (showID, detail)
                        } catch {
                            return (showID, nil)
                        }
                    }
                }

                for await (showID, hydratedShow) in group {
                    if Task.isCancelled {
                        return
                    }

                    if let hydratedShow {
                        hydratedShowsByID[showID] = hydratedShow
                    } else {
                        failedHydrationIDs.insert(showID)
                        failureCount += 1
                    }

                    rebuildSections()
                }
            }
        }

        if Task.isCancelled {
            return
        }

        isHydrating = false

        if failureCount > 0 {
            hydrationErrorMessage = "Some statuses could not be refreshed right now. Showing saved library data."
        }
    }

    private func rebuildSections() {
        let normalizedQuery = searchQuery
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let filteredTrackedShows = trackedShows.filter { tracked in
            guard shelfFilter.includes(tracked.shelf) else {
                return false
            }

            if normalizedQuery.isEmpty {
                return true
            }

            let displayName = hydratedShowsByID[tracked.id]?.name ?? tracked.name
            return displayName.localizedCaseInsensitiveContains(normalizedQuery)
        }

        let items = filteredTrackedShows.map { tracked in
            LibraryDisplayItem(
                tracked: tracked,
                hydratedShow: hydratedShowsByID[tracked.id],
                bucket: bucket(for: tracked)
            )
        }

        let grouped = Dictionary(grouping: items, by: \.bucket)

        let orderedSections = LibraryStatusBucket.allCases.compactMap { bucket -> LibrarySection? in
            guard let bucketItems = grouped[bucket], !bucketItems.isEmpty else {
                return nil
            }

            return LibrarySection(
                bucket: bucket,
                items: sortedItems(bucketItems, for: bucket)
            )
        }

        sections = orderedSections
        summary = makeSummary()
    }

    private func bucket(for tracked: TrackedShow) -> LibraryStatusBucket {
        guard let hydratedShow = hydratedShowsByID[tracked.id] else {
            return .unknown
        }

        switch hydratedShow.bingeableState {
        case .ready:
            return .readyNow
        case .notYet:
            return .notYet
        case .tbd:
            return .unknown
        }
    }

    private func sortedItems(_ items: [LibraryDisplayItem], for bucket: LibraryStatusBucket) -> [LibraryDisplayItem] {
        switch bucket {
        case .readyNow, .unknown:
            return items.sorted { lhs, rhs in
                lhs.tracked.updatedAt > rhs.tracked.updatedAt
            }
        case .notYet:
            return items.sorted { lhs, rhs in
                switch (lhs.nextEpisodeAirDate, rhs.nextEpisodeAirDate) {
                case let (leftDate?, rightDate?):
                    if leftDate != rightDate {
                        return leftDate < rightDate
                    }
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    break
                }

                let nameOrder = lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)
                if nameOrder != .orderedSame {
                    return nameOrder == .orderedAscending
                }

                return lhs.tracked.updatedAt > rhs.tracked.updatedAt
            }
        }
    }

    private func makeSummary() -> LibrarySummary {
        var summary = LibrarySummary()
        summary.totalCount = trackedShows.count
        summary.readyCount = trackedShows.filter { bucket(for: $0) == .readyNow }.count
        summary.watchingCount = trackedShows.filter { $0.shelf == .watching }.count
        summary.waitingCount = trackedShows.filter { $0.shelf == .waiting }.count
        return summary
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0, !isEmpty else {
            return []
        }

        var result: [[Element]] = []
        var index = startIndex

        while index < endIndex {
            let end = self.index(index, offsetBy: size, limitedBy: endIndex) ?? endIndex
            result.append(Array(self[index..<end]))
            index = end
        }

        return result
    }
}
