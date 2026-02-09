import Foundation
import Combine

@MainActor
final class DiscoverViewModel: ObservableObject {
    enum DiscoverActiveSection: String, CaseIterable, Identifiable {
        case trending
        case popular

        var id: String { rawValue }

        var title: String {
            switch self {
            case .trending:
                return "Trending"
            case .popular:
                return "Popular"
            }
        }

        var subtitle: String {
            switch self {
            case .trending:
                return "What everyone is watching right now"
            case .popular:
                return "Series with momentum this week"
            }
        }
    }

    enum DiscoverSortMode: String, CaseIterable, Identifiable {
        case apiOrder
        case alphabetical

        var id: String { rawValue }

        var title: String {
            switch self {
            case .apiOrder:
                return "Default"
            case .alphabetical:
                return "A to Z"
            }
        }

        var shortTitle: String {
            switch self {
            case .apiOrder:
                return "Default"
            case .alphabetical:
                return "A-Z"
            }
        }
    }

    struct DiscoverCategorySection: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let shows: [Show]
        let emptyMessage: String
    }

    @Published var trending: [Show] = []
    @Published var popular: [Show] = []
    @Published var isLoading = false
    @Published var readyToBingeOnly = false
    @Published var inLibraryOnly = false
    @Published var sortMode: DiscoverSortMode = .apiOrder
    @Published var activeSection: DiscoverActiveSection = .trending
    @Published private(set) var isHydratingDetails = false
    @Published var errorMessage: String?

    private var hasLoaded = false
    private var enrichedShowsByID: [Int: Show] = [:]
    private var detailHydrationTask: Task<Void, Never>?

    var visibleTrending: [Show] {
        processed(resolvedTrending, inLibraryIDs: [])
    }

    var visiblePopular: [Show] {
        processed(resolvedPopular, inLibraryIDs: [])
    }

    var readyToBingeShows: [Show] {
        allResolvedUniqueShows.filter { $0.bingeableState == .ready }
    }

    var readySoonShows: [Show] {
        allResolvedUniqueShows
            .filter(isReadySoon)
            .sorted { lhs, rhs in
                switch (lhs.nextEpisodeAirDate, rhs.nextEpisodeAirDate) {
                case let (left?, right?):
                    return left < right
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                default:
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
            }
    }

    var heroShows: [Show] {
        let prioritized = readyToBingeShows + readySoonShows + resolvedTrending + resolvedPopular
        return Array(uniqueShowsPreservingOrder(prioritized).prefix(8))
    }

    var heroShow: Show? {
        heroShows.first
    }

    var categorySections: [DiscoverCategorySection] {
        [
            DiscoverCategorySection(
                id: "trending",
                title: "Trending",
                subtitle: "What everyone is watching right now",
                shows: resolvedTrending,
                emptyMessage: "No trending shows available right now."
            ),
            DiscoverCategorySection(
                id: "popular",
                title: "Popular",
                subtitle: "Series with momentum this week",
                shows: resolvedPopular,
                emptyMessage: "No popular shows available right now."
            ),
            DiscoverCategorySection(
                id: "ready",
                title: "Ready to Binge",
                subtitle: "Shows that are ready to watch now",
                shows: readyToBingeShows,
                emptyMessage: isHydratingDetails ? "Checking what's ready right now..." : "No shows are ready to binge yet."
            ),
            DiscoverCategorySection(
                id: "soon",
                title: "Ready Soon",
                subtitle: "Shows expected to become bingeable soon",
                shows: readySoonShows,
                emptyMessage: isHydratingDetails ? "Estimating upcoming bingeable shows..." : "No upcoming bingeable shows yet."
            )
        ]
    }

    func load(using repository: ShowRepository, force: Bool = false) async {
        guard !hasLoaded || force else {
            return
        }

        await refresh(using: repository)
    }

    func refresh(using repository: ShowRepository) async {
        isLoading = true
        errorMessage = nil
        detailHydrationTask?.cancel()

        do {
            async let trendingTask = repository.trendingShows()
            async let popularTask = repository.popularShows()
            let (trending, popular) = try await (trendingTask, popularTask)

            self.trending = trending
            self.popular = popular
            self.pruneEnrichedShowsToCurrentIDs()
            hasLoaded = true

            startHydratingDetails(using: repository)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func visibleShows(inLibraryIDs: Set<Int>) -> [Show] {
        processed(shows(for: activeSection), inLibraryIDs: inLibraryIDs)
    }

    func shows(for section: DiscoverActiveSection) -> [Show] {
        switch section {
        case .trending:
            return resolvedTrending
        case .popular:
            return resolvedPopular
        }
    }

    private var resolvedTrending: [Show] {
        resolve(trending)
    }

    private var resolvedPopular: [Show] {
        resolve(popular)
    }

    private var allResolvedUniqueShows: [Show] {
        uniqueShowsPreservingOrder(resolve(trending + popular))
    }

    private func processed(_ shows: [Show], inLibraryIDs: Set<Int>) -> [Show] {
        var result = shows

        if readyToBingeOnly {
            result = result.filter { $0.bingeableState == .ready }
        }

        if inLibraryOnly {
            result = result.filter { inLibraryIDs.contains($0.id) }
        }

        if sortMode == .alphabetical {
            result.sort {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }

        return result
    }

    private func resolve(_ shows: [Show]) -> [Show] {
        shows.map { enrichedShowsByID[$0.id] ?? $0 }
    }

    private func isReadySoon(_ show: Show) -> Bool {
        guard show.bingeableState == .notYet else {
            return false
        }

        guard let nextEpisodeAirDate = show.nextEpisodeAirDate else {
            return true
        }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)
        let startOfNextEpisodeDay = calendar.startOfDay(for: nextEpisodeAirDate)
        let daysUntil = calendar.dateComponents([.day], from: startOfToday, to: startOfNextEpisodeDay).day ?? Int.max
        return daysUntil >= 0 && daysUntil <= 28
    }

    private func uniqueShowsPreservingOrder(_ shows: [Show]) -> [Show] {
        var seen = Set<Int>()
        return shows.filter { seen.insert($0.id).inserted }
    }

    private func startHydratingDetails(using repository: ShowRepository) {
        let hydrationIDs = uniqueIDs(from: trending + popular).prefix(24)
        let ids = Array(hydrationIDs)

        guard !ids.isEmpty else {
            isHydratingDetails = false
            return
        }

        detailHydrationTask = Task { [weak self] in
            await self?.hydrateDetails(ids: ids, using: repository)
        }
    }

    private func hydrateDetails(ids: [Int], using repository: ShowRepository) async {
        let idsToFetch = ids.filter { enrichedShowsByID[$0] == nil }
        guard !idsToFetch.isEmpty else {
            isHydratingDetails = false
            return
        }

        isHydratingDetails = true

        var fetchedShows: [Int: Show] = [:]

        await withTaskGroup(of: Show?.self) { group in
            let maxConcurrent = min(6, idsToFetch.count)
            var nextIndex = 0

            while nextIndex < maxConcurrent {
                let id = idsToFetch[nextIndex]
                group.addTask {
                    try? await repository.showDetail(showID: id)
                }
                nextIndex += 1
            }

            while let detailedShow = await group.next() {
                guard !Task.isCancelled else {
                    group.cancelAll()
                    break
                }

                if let detailedShow {
                    fetchedShows[detailedShow.id] = detailedShow
                }

                if nextIndex < idsToFetch.count {
                    let id = idsToFetch[nextIndex]
                    group.addTask {
                        try? await repository.showDetail(showID: id)
                    }
                    nextIndex += 1
                }
            }
        }

        if !Task.isCancelled, !fetchedShows.isEmpty {
            for (id, show) in fetchedShows {
                enrichedShowsByID[id] = show
            }
        }

        isHydratingDetails = false
    }

    private func uniqueIDs(from shows: [Show]) -> [Int] {
        var seen = Set<Int>()
        var ids: [Int] = []

        for show in shows where seen.insert(show.id).inserted {
            ids.append(show.id)
        }

        return ids
    }

    private func pruneEnrichedShowsToCurrentIDs() {
        let currentIDs = Set((trending + popular).map(\.id))
        enrichedShowsByID = enrichedShowsByID.filter { currentIDs.contains($0.key) }
    }
}
