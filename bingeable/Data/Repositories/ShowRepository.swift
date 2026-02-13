import Foundation

protocol ShowRepository: Sendable {
    func trendingShows() async throws -> [Show]
    func popularShows() async throws -> [Show]
    func searchShows(query: String) async throws -> [Show]
    func showDetail(showID: Int) async throws -> Show
    func watchProviders(showID: Int) async throws -> [WatchProvider]
    func seasonEpisodes(showID: Int, seasonNumber: Int) async throws -> [ShowEpisode]
    func clearCache() async
}

extension ShowRepository {
    func seasonEpisodes(showID _: Int, seasonNumber _: Int) async throws -> [ShowEpisode] {
        []
    }
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

    private struct SeasonKey: Hashable {
        let showID: Int
        let seasonNumber: Int
    }

    private let client: TMDBClient
    private let detailCache: ShowDetailCache
    private let regionCode: String
    private let listCacheTTL: TimeInterval

    private var listCache: [ListKind: ListCacheEntry] = [:]
    private var detailTasks: [Int: Task<Show, Error>] = [:]
    private var providerTasks: [Int: Task<[WatchProvider], Error>] = [:]
    private var seasonEpisodeTasks: [SeasonKey: Task<[ShowEpisode], Error>] = [:]
    private var genreLookup: [Int: Genre] = [:]
    private var genreLookupTask: Task<[Int: Genre], Error>?

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
            let genres = await currentGenreLookup()
            let response = try await client.searchTV(query: trimmed)
            return response.map { Self.mapSummary($0, genreLookup: genres) }
        } catch TMDBError.missingAPIKey {
            return ShowFixtures.shows.filter {
                $0.name.localizedCaseInsensitiveContains(trimmed)
                    || $0.overview.localizedCaseInsensitiveContains(trimmed)
            }
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

    func seasonEpisodes(showID: Int, seasonNumber: Int) async throws -> [ShowEpisode] {
        guard seasonNumber > 0 else {
            return []
        }

        let key = SeasonKey(showID: showID, seasonNumber: seasonNumber)
        if let task = seasonEpisodeTasks[key] {
            return try await task.value
        }

        let task = Task<[ShowEpisode], Error> {
            do {
                let response = try await client.seasonDetail(showID: showID, seasonNumber: seasonNumber)
                return Self.mapSeasonEpisodes(response.episodes)
            } catch TMDBError.missingAPIKey {
                return ShowFixtures.seasonEpisodes[showID]?[seasonNumber] ?? []
            }
        }

        seasonEpisodeTasks[key] = task
        defer { seasonEpisodeTasks[key] = nil }
        return try await task.value
    }

    func clearCache() async {
        listCache.removeAll()
        detailTasks.removeAll()
        providerTasks.removeAll()
        seasonEpisodeTasks.removeAll()
        genreLookup.removeAll()
        genreLookupTask?.cancel()
        genreLookupTask = nil
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
        mapSummary(dto, genreLookup: [:])
    }

    nonisolated private static func mapSummary(_ dto: TMDBShowSummaryDTO, genreLookup: [Int: Genre]) -> Show {
        let genres = (dto.genreIds ?? []).compactMap { genreLookup[$0] }

        return Show(
            id: dto.id,
            name: dto.name,
            posterPath: dto.posterPath,
            overview: dto.overview,
            genres: genres,
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
        let seasons = dto.seasons?
            .filter { $0.seasonNumber > 0 }
            .map { season in
                let trimmedName = season.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return ShowSeason(
                    seasonNumber: season.seasonNumber,
                    name: trimmedName.isEmpty ? "Season \(season.seasonNumber)" : trimmedName,
                    airDate: DateParsing.parseTMDBDate(season.airDate),
                    episodeCount: season.episodeCount
                )
            }

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
            voteCount: dto.voteCount,
            seasons: seasons
        )
    }

    nonisolated private static func mapSeasonEpisodes(_ episodes: [TMDBSeasonEpisodeDTO]) -> [ShowEpisode] {
        episodes
            .compactMap { dto in
                guard let episodeNumber = dto.episodeNumber, episodeNumber > 0 else {
                    return nil
                }

                let trimmedName = dto.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let normalizedName = trimmedName.isEmpty ? "Episode \(episodeNumber)" : trimmedName

                return ShowEpisode(
                    episodeNumber: episodeNumber,
                    name: normalizedName,
                    airDate: DateParsing.parseTMDBDate(dto.airDate),
                    overview: dto.overview?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                    runtimeMinutes: dto.runtime
                )
            }
            .sorted { lhs, rhs in
                lhs.episodeNumber < rhs.episodeNumber
            }
    }

    private func currentGenreLookup() async -> [Int: Genre] {
        if !genreLookup.isEmpty {
            return genreLookup
        }

        if let task = genreLookupTask {
            return (try? await task.value) ?? [:]
        }

        let task = Task<[Int: Genre], Error> {
            let remoteGenres = try await client.tvGenres()
            return Dictionary(
                uniqueKeysWithValues: remoteGenres.map { dto in
                    (dto.id, Genre(id: dto.id, name: dto.name))
                }
            )
        }

        genreLookupTask = task
        defer { genreLookupTask = nil }

        do {
            let resolved = try await task.value
            genreLookup = resolved
            return resolved
        } catch {
            return [:]
        }
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
            voteCount: 14500,
            seasons: [
                ShowSeason(seasonNumber: 1, name: "Season 1", airDate: DateParsing.parseTMDBDate("2008-01-20"), episodeCount: 7),
                ShowSeason(seasonNumber: 2, name: "Season 2", airDate: DateParsing.parseTMDBDate("2009-03-08"), episodeCount: 13),
                ShowSeason(seasonNumber: 3, name: "Season 3", airDate: DateParsing.parseTMDBDate("2010-03-21"), episodeCount: 13),
                ShowSeason(seasonNumber: 4, name: "Season 4", airDate: DateParsing.parseTMDBDate("2011-07-17"), episodeCount: 13),
                ShowSeason(seasonNumber: 5, name: "Season 5", airDate: DateParsing.parseTMDBDate("2012-07-15"), episodeCount: 16)
            ]
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
            voteCount: 4200,
            seasons: [
                ShowSeason(seasonNumber: 1, name: "Season 1", airDate: DateParsing.parseTMDBDate("2021-11-06"), episodeCount: 9),
                ShowSeason(seasonNumber: 2, name: "Season 2", airDate: DateParsing.parseTMDBDate("2024-11-09"), episodeCount: 9)
            ]
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
            voteCount: 5100,
            seasons: [
                ShowSeason(seasonNumber: 1, name: "Season 1", airDate: DateParsing.parseTMDBDate("2022-08-21"), episodeCount: 10),
                ShowSeason(seasonNumber: 2, name: "Season 2", airDate: DateParsing.parseTMDBDate("2024-06-16"), episodeCount: 8)
            ]
        )
    ]

    nonisolated static let providers: [WatchProvider] = [
        WatchProvider(id: 8, name: "Netflix", logoPath: nil),
        WatchProvider(id: 337, name: "Disney Plus", logoPath: nil),
        WatchProvider(id: 384, name: "HBO Max", logoPath: nil)
    ]

    nonisolated static let seasonEpisodes: [Int: [Int: [ShowEpisode]]] = [
        1396: [
            1: [
                ShowEpisode(
                    episodeNumber: 1,
                    name: "Pilot",
                    airDate: DateParsing.parseTMDBDate("2008-01-20"),
                    overview: "Walter White begins a dangerous new path after a life-changing diagnosis.",
                    runtimeMinutes: 58
                ),
                ShowEpisode(
                    episodeNumber: 2,
                    name: "Cat's in the Bag...",
                    airDate: DateParsing.parseTMDBDate("2008-01-27"),
                    overview: "Walt and Jesse deal with the consequences of their first cook.",
                    runtimeMinutes: 48
                )
            ],
            2: [
                ShowEpisode(
                    episodeNumber: 1,
                    name: "Seven Thirty-Seven",
                    airDate: DateParsing.parseTMDBDate("2009-03-08"),
                    overview: "Tuco escalates pressure on Walt and Jesse after their encounter.",
                    runtimeMinutes: 47
                )
            ]
        ],
        94605: [
            1: [
                ShowEpisode(
                    episodeNumber: 1,
                    name: "Welcome to the Playground",
                    airDate: DateParsing.parseTMDBDate("2021-11-06"),
                    overview: "In Piltover and Zaun, simmering tensions push sisters onto separate paths.",
                    runtimeMinutes: 41
                )
            ],
            2: [
                ShowEpisode(
                    episodeNumber: 1,
                    name: "Heavy Is the Crown",
                    airDate: DateParsing.parseTMDBDate("2024-11-09"),
                    overview: "New alliances and old wounds collide as conflict expands.",
                    runtimeMinutes: 44
                )
            ]
        ],
        94997: [
            1: [
                ShowEpisode(
                    episodeNumber: 1,
                    name: "The Heirs of the Dragon",
                    airDate: DateParsing.parseTMDBDate("2022-08-21"),
                    overview: "The succession question reshapes alliances in King Viserys' court.",
                    runtimeMinutes: 66
                )
            ],
            2: [
                ShowEpisode(
                    episodeNumber: 1,
                    name: "A Son for a Son",
                    airDate: DateParsing.parseTMDBDate("2024-06-16"),
                    overview: "The houses prepare for retaliation as open war approaches.",
                    runtimeMinutes: 64
                )
            ]
        ]
    ]
}
