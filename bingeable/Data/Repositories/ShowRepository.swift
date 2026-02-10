import Foundation

protocol ShowRepository: Sendable {
    func trendingShows() async throws -> [Show]
    func popularShows() async throws -> [Show]
    func searchShows(query: String) async throws -> [Show]
    func showDetail(showID: Int) async throws -> Show
    func watchProviders(showID: Int) async throws -> [WatchProvider]
    func clearCache() async
}

actor TMDBShowRepository: ShowRepository {
    private enum ListKind: Hashable {
        case trending
        case popular
    }

    private struct ListCacheEntry {
        let value: [Show]
        let timestamp: Date
    }

    private let client: TMDBClient
    private let detailCache: ShowDetailCache
    private let regionCode: String
    private let listCacheTTL: TimeInterval

    private var listCache: [ListKind: ListCacheEntry] = [:]
    private var detailTasks: [Int: Task<Show, Error>] = [:]
    private var providerTasks: [Int: Task<[WatchProvider], Error>] = [:]

    init(
        client: TMDBClient,
        detailCache: ShowDetailCache,
        regionProvider: RegionProviding,
        listCacheTTL: TimeInterval = 300
    ) {
        self.client = client
        self.detailCache = detailCache
        self.regionCode = regionProvider.regionCode
        self.listCacheTTL = listCacheTTL
    }

    func trendingShows() async throws -> [Show] {
        try await cachedList(for: .trending) {
            let response = try await client.trendingTV()
            return response.map(Self.mapSummary)
        } fallback: {
            ShowFixtures.shows
        }
    }

    func popularShows() async throws -> [Show] {
        try await cachedList(for: .popular) {
            let response = try await client.popularTV()
            return response.map(Self.mapSummary)
        } fallback: {
            ShowFixtures.shows
        }
    }

    func searchShows(query: String) async throws -> [Show] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return []
        }

        do {
            let response = try await client.searchTV(query: trimmed)
            return response.map(Self.mapSummary)
        } catch TMDBError.missingAPIKey {
            return ShowFixtures.shows.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
        }
    }

    func showDetail(showID: Int) async throws -> Show {
        if let task = detailTasks[showID] {
            return try await task.value
        }

        let task = Task<Show, Error> {
            do {
                let dto = try await client.showDetail(id: showID)
                let mapped = Self.mapDetail(dto)
                await detailCache.set(mapped)
                return mapped
            } catch TMDBError.missingAPIKey {
                if let fixture = ShowFixtures.shows.first(where: { $0.id == showID }) {
                    return fixture
                }

                if let cached = await detailCache.value(for: showID) {
                    return cached
                }

                throw TMDBError.missingAPIKey
            } catch {
                if let cached = await detailCache.value(for: showID) {
                    return cached
                }
                throw error
            }
        }

        detailTasks[showID] = task
        defer { detailTasks[showID] = nil }
        return try await task.value
    }

    func watchProviders(showID: Int) async throws -> [WatchProvider] {
        if let task = providerTasks[showID] {
            return try await task.value
        }

        let task = Task<[WatchProvider], Error> {
            do {
                let response = try await client.watchProviders(id: showID)
                let allResults = response.results
                let region = allResults[regionCode] ?? allResults["US"] ?? allResults.values.first
                let providers = region?.flatrate ?? []
                return providers.map {
                    WatchProvider(id: $0.providerId, name: $0.providerName, logoPath: $0.logoPath)
                }
            } catch TMDBError.missingAPIKey {
                return ShowFixtures.providers
            }
        }

        providerTasks[showID] = task
        defer { providerTasks[showID] = nil }
        return try await task.value
    }

    func clearCache() async {
        listCache.removeAll()
        detailTasks.removeAll()
        providerTasks.removeAll()
        await client.clearURLCache()
        await detailCache.clear()
    }

    private func cachedList(
        for kind: ListKind,
        loader: () async throws -> [Show],
        fallback: () -> [Show]
    ) async throws -> [Show] {
        if let entry = listCache[kind], Date().timeIntervalSince(entry.timestamp) < listCacheTTL {
            return entry.value
        }

        do {
            let value = try await loader()
            listCache[kind] = ListCacheEntry(value: value, timestamp: .now)
            return value
        } catch TMDBError.missingAPIKey {
            return fallback()
        }
    }

    nonisolated private static func mapSummary(_ dto: TMDBShowSummaryDTO) -> Show {
        Show(
            id: dto.id,
            name: dto.name,
            posterPath: dto.posterPath,
            overview: dto.overview,
            genres: [],
            status: nil,
            lastAirDate: nil,
            nextEpisodeAirDate: nil,
            airedEpisodeCount: nil,
            voteAverage: dto.voteAverage,
            voteCount: dto.voteCount
        )
    }

    nonisolated private static func mapDetail(_ dto: TMDBShowDetailDTO) -> Show {
        let genres = dto.genres.map { Genre(id: $0.id, name: $0.name) }
        let airedCount = dto.lastEpisodeToAir?.episodeNumber ?? dto.numberOfEpisodes

        return Show(
            id: dto.id,
            name: dto.name,
            posterPath: dto.posterPath,
            overview: dto.overview,
            genres: genres,
            status: ShowStatus(tmdbValue: dto.status),
            lastAirDate: DateParsing.parseTMDBDate(dto.lastAirDate),
            nextEpisodeAirDate: DateParsing.parseTMDBDate(dto.nextEpisodeToAir?.airDate),
            airedEpisodeCount: airedCount,
            voteAverage: dto.voteAverage,
            voteCount: dto.voteCount
        )
    }
}

private enum ShowFixtures {
    nonisolated static let shows: [Show] = [
        Show(
            id: 1396,
            name: "Breaking Bad",
            posterPath: nil,
            overview: "A high school chemistry teacher turns to manufacturing methamphetamine.",
            genres: [Genre(id: 18, name: "Drama")],
            status: .ended,
            lastAirDate: DateParsing.parseTMDBDate("2013-09-29"),
            nextEpisodeAirDate: nil,
            airedEpisodeCount: 62,
            voteAverage: 8.9,
            voteCount: 14500
        ),
        Show(
            id: 94605,
            name: "Arcane",
            posterPath: nil,
            overview: "Two sisters are torn apart by opposing sides of a war between technologies and convictions.",
            genres: [Genre(id: 16, name: "Animation")],
            status: .ended,
            lastAirDate: DateParsing.parseTMDBDate("2024-11-23"),
            nextEpisodeAirDate: nil,
            airedEpisodeCount: 18,
            voteAverage: 8.7,
            voteCount: 4200
        ),
        Show(
            id: 94997,
            name: "House of the Dragon",
            posterPath: nil,
            overview: "The Targaryen dynasty is at the absolute apex of its power.",
            genres: [Genre(id: 10765, name: "Sci-Fi & Fantasy")],
            status: .returningSeries,
            lastAirDate: DateParsing.parseTMDBDate("2024-08-04"),
            nextEpisodeAirDate: DateParsing.parseTMDBDate("2026-06-14"),
            airedEpisodeCount: 18,
            voteAverage: 8.3,
            voteCount: 5100
        )
    ]

    nonisolated static let providers: [WatchProvider] = [
        WatchProvider(id: 8, name: "Netflix", logoPath: nil),
        WatchProvider(id: 337, name: "Disney Plus", logoPath: nil),
        WatchProvider(id: 384, name: "HBO Max", logoPath: nil)
    ]
}
