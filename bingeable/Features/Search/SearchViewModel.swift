import Foundation
import Combine

@MainActor
final class SearchViewModel: ObservableObject {
    enum SearchSortOption: String, CaseIterable, Identifiable {
        case relevance
        case rating
        case alphabetical

        var id: String { rawValue }

        var title: String {
            switch self {
            case .relevance:
                return "Relevance"
            case .rating:
                return "Rating"
            case .alphabetical:
                return "A-Z"
            }
        }
    }

    static let allGenresLabel = "All Genres"

    @Published var query = ""
    @Published private(set) var displayedResults: [Show] = []
    @Published private(set) var totalResultCount = 0
    @Published var isSearching = false
    @Published var errorMessage: String?
    @Published private(set) var recentShows: [Show] = []
    @Published private(set) var availableGenres: [String] = [SearchViewModel.allGenresLabel]
    @Published var selectedGenre = SearchViewModel.allGenresLabel {
        didSet {
            applyTransforms()
        }
    }
    @Published var sortOption: SearchSortOption = .relevance {
        didSet {
            applyTransforms()
        }
    }

    private let minimumQueryLength: Int
    private let debounceNanoseconds: UInt64
    private let sleeper: @Sendable (UInt64) async throws -> Void

    private var rawResults: [Show] = []
    private var searchTask: Task<Void, Never>?
    private var searchRequestSequence = 0

    init(
        minimumQueryLength: Int = 2,
        debounceMilliseconds: UInt64 = 350,
        sleeper: @escaping @Sendable (UInt64) async throws -> Void = { nanoseconds in
            try await Task.sleep(nanoseconds: nanoseconds)
        }
    ) {
        self.minimumQueryLength = minimumQueryLength
        self.debounceNanoseconds = debounceMilliseconds * 1_000_000
        self.sleeper = sleeper
    }

    deinit {
        searchTask?.cancel()
    }

    var trimmedQuery: String {
        normalizeQuery(query)
    }

    var isQueryEmpty: Bool {
        trimmedQuery.isEmpty
    }

    var isBelowMinimumQueryLength: Bool {
        let length = trimmedQuery.count
        return length > 0 && length < minimumQueryLength
    }

    var shouldShowRecents: Bool {
        (isQueryEmpty || isBelowMinimumQueryLength) && !recentShows.isEmpty
    }

    var shouldShowInitialPrompt: Bool {
        isQueryEmpty && recentShows.isEmpty
    }

    var shouldShowMinimumQueryHint: Bool {
        isBelowMinimumQueryLength
    }

    var shouldShowFilters: Bool {
        !rawResults.isEmpty
    }

    var shouldShowNoResultsState: Bool {
        !isSearching && errorMessage == nil && !isQueryEmpty && !isBelowMinimumQueryLength && rawResults.isEmpty
    }

    func loadRecentShows(from store: any RecentSearchPersisting) {
        recentShows = store.recentShows()
    }

    func clearRecentShows(using store: any RecentSearchPersisting) {
        store.clearAll()
        loadRecentShows(from: store)
    }

    func recordViewedShow(_ show: Show, using store: any RecentSearchPersisting) {
        store.record(show: show)
        loadRecentShows(from: store)
    }

    func handleQueryChange(using repository: any ShowRepository, recentSearchStore: any RecentSearchPersisting) {
        scheduleSearch(
            using: repository,
            recentSearchStore: recentSearchStore,
            debounce: true
        )
    }

    private func scheduleSearch(
        using repository: any ShowRepository,
        recentSearchStore: any RecentSearchPersisting,
        debounce: Bool
    ) {
        let trimmed = trimmedQuery

        searchTask?.cancel()
        searchRequestSequence += 1
        let requestSequence = searchRequestSequence
        errorMessage = nil

        guard !trimmed.isEmpty else {
            isSearching = false
            applySearchResults([])
            loadRecentShows(from: recentSearchStore)
            return
        }

        guard trimmed.count >= minimumQueryLength else {
            isSearching = false
            applySearchResults([])
            loadRecentShows(from: recentSearchStore)
            return
        }

        isSearching = true
        let debounceNanoseconds = self.debounceNanoseconds
        let sleeper = self.sleeper

        searchTask = Task {
            do {
                if debounce {
                    try await sleeper(debounceNanoseconds)
                }

                try Task.checkCancellation()
                let fetched = try await repository.searchShows(query: trimmed)
                try Task.checkCancellation()

                await MainActor.run {
                    guard requestSequence == self.searchRequestSequence else {
                        return
                    }

                    self.errorMessage = nil
                    self.isSearching = false
                    self.applySearchResults(fetched)
                }
            } catch is CancellationError {
                await MainActor.run {
                    if requestSequence == self.searchRequestSequence {
                        self.isSearching = false
                    }
                }
            } catch {
                await MainActor.run {
                    guard requestSequence == self.searchRequestSequence else {
                        return
                    }

                    self.errorMessage = error.localizedDescription
                    self.isSearching = false
                }
            }
        }
    }

    private func applySearchResults(_ results: [Show]) {
        rawResults = results
        totalResultCount = results.count
        refreshAvailableGenres()
        applyTransforms()
    }

    private func refreshAvailableGenres() {
        let names = Set(
            rawResults
                .flatMap(\.genres)
                .map(\.name)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )

        availableGenres = [Self.allGenresLabel] + names.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }

        if !availableGenres.contains(selectedGenre) {
            selectedGenre = Self.allGenresLabel
        }
    }

    private func applyTransforms() {
        var transformed = rawResults

        if selectedGenre != Self.allGenresLabel {
            transformed = transformed.filter { show in
                show.genres.contains(where: { genre in
                    genre.name.localizedCaseInsensitiveCompare(selectedGenre) == .orderedSame
                })
            }
        }

        switch sortOption {
        case .relevance:
            break
        case .rating:
            transformed.sort { lhs, rhs in
                let lhsRating = lhs.voteAverage ?? 0
                let rhsRating = rhs.voteAverage ?? 0
                if lhsRating != rhsRating {
                    return lhsRating > rhsRating
                }

                let lhsVotes = lhs.voteCount ?? 0
                let rhsVotes = rhs.voteCount ?? 0
                if lhsVotes != rhsVotes {
                    return lhsVotes > rhsVotes
                }

                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        case .alphabetical:
            transformed.sort {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }

        displayedResults = transformed
    }

    private func normalizeQuery(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
