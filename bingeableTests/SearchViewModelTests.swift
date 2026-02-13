import Foundation
import Testing
@testable import bingeable

struct SearchViewModelTests {

    @Test("Search debounce only sends latest request")
    @MainActor
    func debounceSendsOnlyLatestRequest() async throws {
        let repository = MockSearchRepository(
            resultsByQuery: [
                "bre": [makeShow(id: 1, name: "Breaking Bad", genres: [Genre(id: 18, name: "Drama")])]
            ]
        )
        let viewModel = SearchViewModel(debounceMilliseconds: 80)
        let recentStore = MockRecentSearchStore()

        viewModel.query = "br"
        viewModel.handleQueryChange(using: repository, recentSearchStore: recentStore)

        try await Task.sleep(nanoseconds: 20_000_000)

        viewModel.query = "bre"
        viewModel.handleQueryChange(using: repository, recentSearchStore: recentStore)

        try await Task.sleep(nanoseconds: 220_000_000)

        let searchedQueries = await repository.searchedQueries()
        #expect(searchedQueries == ["bre"])
        #expect(viewModel.displayedResults.map(\.name) == ["Breaking Bad"])
    }

    @Test("Search ignores queries shorter than minimum length")
    @MainActor
    func shortQueriesDoNotTriggerSearch() async throws {
        let repository = MockSearchRepository(resultsByQuery: [:])
        let viewModel = SearchViewModel(debounceMilliseconds: 30)
        let recentStore = MockRecentSearchStore()

        viewModel.query = "a"
        viewModel.handleQueryChange(using: repository, recentSearchStore: recentStore)

        try await Task.sleep(nanoseconds: 120_000_000)

        let searchedQueries = await repository.searchedQueries()
        #expect(searchedQueries.isEmpty)
        #expect(viewModel.displayedResults.isEmpty)
        #expect(viewModel.shouldShowMinimumQueryHint)
    }

    @Test("Latest completed search wins when earlier request is slower")
    @MainActor
    func staleResultsAreIgnored() async throws {
        let repository = MockSearchRepository(
            resultsByQuery: [
                "bre": [makeShow(id: 1, name: "Breaking Bad", genres: [Genre(id: 18, name: "Drama")])],
                "arc": [makeShow(id: 2, name: "Arcane", genres: [Genre(id: 16, name: "Animation")])]
            ],
            delaysByQuery: [
                "bre": 220_000_000,
                "arc": 20_000_000
            ]
        )
        let viewModel = SearchViewModel(debounceMilliseconds: 20)
        let recentStore = MockRecentSearchStore()

        viewModel.query = "bre"
        viewModel.handleQueryChange(using: repository, recentSearchStore: recentStore)

        try await Task.sleep(nanoseconds: 60_000_000)

        viewModel.query = "arc"
        viewModel.handleQueryChange(using: repository, recentSearchStore: recentStore)

        try await Task.sleep(nanoseconds: 300_000_000)

        #expect(viewModel.displayedResults.map(\.name) == ["Arcane"])
    }

    @Test("Search sorting supports relevance rating and alphabetical")
    @MainActor
    func sortingModesApplyCorrectly() async throws {
        let alpha = makeShow(id: 1, name: "Alpha", rating: 8.1, votes: 100, genres: [Genre(id: 18, name: "Drama")])
        let beta = makeShow(id: 2, name: "Beta", rating: 9.0, votes: 50, genres: [Genre(id: 35, name: "Comedy")])
        let gamma = makeShow(id: 3, name: "Gamma", rating: 9.0, votes: 400, genres: [Genre(id: 16, name: "Animation")])

        let repository = MockSearchRepository(
            resultsByQuery: [
                "show": [beta, alpha, gamma]
            ]
        )
        let viewModel = SearchViewModel(debounceMilliseconds: 1)
        let recentStore = MockRecentSearchStore()

        viewModel.query = "show"
        viewModel.handleQueryChange(using: repository, recentSearchStore: recentStore)
        try await Task.sleep(nanoseconds: 80_000_000)

        #expect(viewModel.displayedResults.map(\.name) == ["Beta", "Alpha", "Gamma"])

        viewModel.sortOption = .rating
        #expect(viewModel.displayedResults.map(\.name) == ["Gamma", "Beta", "Alpha"])

        viewModel.sortOption = .alphabetical
        #expect(viewModel.displayedResults.map(\.name) == ["Alpha", "Beta", "Gamma"])
    }

    @Test("Genre filter options are derived from returned results")
    @MainActor
    func genreFilteringUsesDetectedGenres() async throws {
        let repository = MockSearchRepository(
            resultsByQuery: [
                "tv": [
                    makeShow(id: 1, name: "Drama Show", genres: [Genre(id: 18, name: "Drama")]),
                    makeShow(id: 2, name: "Comedy Show", genres: [Genre(id: 35, name: "Comedy")]),
                    makeShow(id: 3, name: "Hybrid Show", genres: [Genre(id: 18, name: "Drama"), Genre(id: 35, name: "Comedy")])
                ]
            ]
        )
        let viewModel = SearchViewModel(debounceMilliseconds: 1)
        let recentStore = MockRecentSearchStore()

        viewModel.query = "tv"
        viewModel.handleQueryChange(using: repository, recentSearchStore: recentStore)
        try await Task.sleep(nanoseconds: 80_000_000)

        #expect(viewModel.availableGenres == ["All Genres", "Comedy", "Drama"])

        viewModel.selectedGenre = "Drama"
        #expect(viewModel.displayedResults.map(\.name) == ["Drama Show", "Hybrid Show"])

        viewModel.selectedGenre = "All Genres"
        #expect(viewModel.displayedResults.count == 3)
    }

    @Test("Recent searches are deduped capped and clearable")
    @MainActor
    func recentSearchesPersistWithCapAndDedupe() async throws {
        let repository = MockSearchRepository(resultsByQuery: [:], defaultResult: [makeShow(id: 99, name: "Fallback", genres: [])])
        let viewModel = SearchViewModel(debounceMilliseconds: 1)
        let recentStore = MockRecentSearchStore()

        for index in 0..<10 {
            let query = "show\(index)"
            viewModel.query = query
            viewModel.handleQueryChange(using: repository, recentSearchStore: recentStore)
            try await Task.sleep(nanoseconds: 45_000_000)
        }

        viewModel.query = "SHOW9"
        viewModel.handleQueryChange(using: repository, recentSearchStore: recentStore)
        try await Task.sleep(nanoseconds: 45_000_000)

        viewModel.loadRecentQueries(from: recentStore)

        #expect(viewModel.recentQueries.count == 8)
        #expect(viewModel.recentQueries.first == "SHOW9")
        #expect(viewModel.recentQueries.contains("show2"))
        #expect(!viewModel.recentQueries.contains("show1"))
        #expect(Set(viewModel.recentQueries.map { $0.lowercased() }).count == viewModel.recentQueries.count)

        viewModel.clearRecentQueries(using: recentStore)
        #expect(viewModel.recentQueries.isEmpty)
    }

    private func makeShow(
        id: Int,
        name: String,
        rating: Double = 8.0,
        votes: Int = 100,
        genres: [Genre]
    ) -> Show {
        Show(
            id: id,
            name: name,
            posterPath: nil,
            overview: "Overview for \(name)",
            genres: genres,
            status: .ended,
            lastAirDate: nil,
            nextEpisodeAirDate: nil,
            airedEpisodeCount: 10,
            voteAverage: rating,
            voteCount: votes
        )
    }

    private actor MockSearchRepository: ShowRepository {
        let resultsByQuery: [String: [Show]]
        let delaysByQuery: [String: UInt64]
        let defaultResult: [Show]
        var queries: [String] = []

        init(
            resultsByQuery: [String: [Show]],
            delaysByQuery: [String: UInt64] = [:],
            defaultResult: [Show] = []
        ) {
            self.resultsByQuery = resultsByQuery
            self.delaysByQuery = delaysByQuery
            self.defaultResult = defaultResult
        }

        func trendingShows() async throws -> [Show] {
            []
        }

        func popularShows() async throws -> [Show] {
            []
        }

        func searchShows(query: String) async throws -> [Show] {
            queries.append(query)

            if let delay = delaysByQuery[query], delay > 0 {
                try await Task.sleep(nanoseconds: delay)
            }

            return resultsByQuery[query] ?? defaultResult
        }

        func showDetail(showID _: Int) async throws -> Show {
            throw MockError.unimplemented
        }

        func watchProviders(showID _: Int) async throws -> [WatchProvider] {
            []
        }

        func clearCache() async {}

        func searchedQueries() -> [String] {
            queries
        }
    }

    private enum MockError: Error {
        case unimplemented
    }

    @MainActor
    private final class MockRecentSearchStore: RecentSearchPersisting {
        private struct Entry {
            var normalized: String
            var display: String
            var updatedAt: Date
        }

        private var entries: [Entry] = []
        private let maxEntries = 8

        func recentQueries() -> [String] {
            entries
                .sorted { $0.updatedAt > $1.updatedAt }
                .map(\.display)
        }

        func record(query: String) {
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return
            }

            let normalized = normalize(trimmed)
            if let existingIndex = entries.firstIndex(where: { $0.normalized == normalized }) {
                entries[existingIndex].display = trimmed
                entries[existingIndex].updatedAt = .now
            } else {
                entries.append(
                    Entry(
                        normalized: normalized,
                        display: trimmed,
                        updatedAt: .now
                    )
                )
            }

            entries.sort { $0.updatedAt > $1.updatedAt }
            if entries.count > maxEntries {
                entries.removeLast(entries.count - maxEntries)
            }
        }

        func clearAll() {
            entries.removeAll()
        }

        private func normalize(_ query: String) -> String {
            query
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
        }
    }
}
