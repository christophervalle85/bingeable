import Foundation

actor PreviewShowRepository: ShowRepository {
    private enum PreviewRepositoryError: LocalizedError {
        case showNotFound

        var errorDescription: String? {
            switch self {
            case .showNotFound:
                return "Show not found in preview fixtures."
            }
        }
    }

    private nonisolated static let fixtureShows: [Show] = [
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
            id: 2316,
            name: "The Office",
            posterPath: nil,
            overview: "A mockumentary on a group of typical office workers in Scranton, Pennsylvania.",
            genres: [Genre(id: 35, name: "Comedy")],
            status: .ended,
            lastAirDate: DateParsing.parseTMDBDate("2013-05-16"),
            nextEpisodeAirDate: nil,
            airedEpisodeCount: 201,
            voteAverage: 8.6,
            voteCount: 2900,
            seasons: [
                ShowSeason(seasonNumber: 1, name: "Season 1", airDate: DateParsing.parseTMDBDate("2005-03-24"), episodeCount: 6),
                ShowSeason(seasonNumber: 2, name: "Season 2", airDate: DateParsing.parseTMDBDate("2005-09-20"), episodeCount: 22),
                ShowSeason(seasonNumber: 3, name: "Season 3", airDate: DateParsing.parseTMDBDate("2006-09-21"), episodeCount: 25),
                ShowSeason(seasonNumber: 4, name: "Season 4", airDate: DateParsing.parseTMDBDate("2007-09-27"), episodeCount: 19),
                ShowSeason(seasonNumber: 5, name: "Season 5", airDate: DateParsing.parseTMDBDate("2008-09-25"), episodeCount: 28),
                ShowSeason(seasonNumber: 6, name: "Season 6", airDate: DateParsing.parseTMDBDate("2009-09-17"), episodeCount: 26),
                ShowSeason(seasonNumber: 7, name: "Season 7", airDate: DateParsing.parseTMDBDate("2010-09-23"), episodeCount: 26),
                ShowSeason(seasonNumber: 8, name: "Season 8", airDate: DateParsing.parseTMDBDate("2011-09-22"), episodeCount: 24),
                ShowSeason(seasonNumber: 9, name: "Season 9", airDate: DateParsing.parseTMDBDate("2012-09-20"), episodeCount: 25)
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
        ),
        Show(
            id: 1429,
            name: "Attack on Titan",
            posterPath: nil,
            overview: "After his hometown is destroyed, Eren Jaeger vows to wipe out the Titans.",
            genres: [Genre(id: 16, name: "Animation")],
            status: .ended,
            lastAirDate: DateParsing.parseTMDBDate("2023-11-04"),
            nextEpisodeAirDate: nil,
            airedEpisodeCount: 94,
            voteAverage: 8.7,
            voteCount: 6400,
            seasons: [
                ShowSeason(seasonNumber: 1, name: "Season 1", airDate: DateParsing.parseTMDBDate("2013-04-07"), episodeCount: 25),
                ShowSeason(seasonNumber: 2, name: "Season 2", airDate: DateParsing.parseTMDBDate("2017-04-01"), episodeCount: 12),
                ShowSeason(seasonNumber: 3, name: "Season 3", airDate: DateParsing.parseTMDBDate("2018-07-23"), episodeCount: 22),
                ShowSeason(seasonNumber: 4, name: "Season 4", airDate: DateParsing.parseTMDBDate("2020-12-07"), episodeCount: 30),
                ShowSeason(seasonNumber: 5, name: "Season 5", airDate: DateParsing.parseTMDBDate("2023-03-04"), episodeCount: 5)
            ]
        ),
        Show(
            id: 66732,
            name: "Stranger Things",
            posterPath: nil,
            overview: "A group of kids uncover supernatural mysteries in their small town.",
            genres: [Genre(id: 18, name: "Drama")],
            status: .returningSeries,
            lastAirDate: DateParsing.parseTMDBDate("2022-07-01"),
            nextEpisodeAirDate: DateParsing.parseTMDBDate("2026-10-09"),
            airedEpisodeCount: 34,
            voteAverage: 8.6,
            voteCount: 18200,
            seasons: [
                ShowSeason(seasonNumber: 1, name: "Season 1", airDate: DateParsing.parseTMDBDate("2016-07-15"), episodeCount: 8),
                ShowSeason(seasonNumber: 2, name: "Season 2", airDate: DateParsing.parseTMDBDate("2017-10-27"), episodeCount: 9),
                ShowSeason(seasonNumber: 3, name: "Season 3", airDate: DateParsing.parseTMDBDate("2019-07-04"), episodeCount: 8),
                ShowSeason(seasonNumber: 4, name: "Season 4", airDate: DateParsing.parseTMDBDate("2022-05-27"), episodeCount: 9)
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
        )
    ]

    private nonisolated static let fixtureProviders: [WatchProvider] = [
        WatchProvider(id: 8, name: "Netflix", logoPath: nil),
        WatchProvider(id: 337, name: "Disney Plus", logoPath: nil),
        WatchProvider(id: 384, name: "HBO Max", logoPath: nil)
    ]

    private nonisolated static let fixtureSeasonEpisodes: [Int: [Int: [ShowEpisode]]] = [
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
            ]
        ],
        2316: [
            1: [
                ShowEpisode(
                    episodeNumber: 1,
                    name: "Pilot",
                    airDate: DateParsing.parseTMDBDate("2005-03-24"),
                    overview: "A documentary crew starts following the Dunder Mifflin Scranton branch.",
                    runtimeMinutes: 23
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
        ],
        66732: [
            1: [
                ShowEpisode(
                    episodeNumber: 1,
                    name: "Chapter One: The Vanishing of Will Byers",
                    airDate: DateParsing.parseTMDBDate("2016-07-15"),
                    overview: "A young boy disappears and a strange girl appears in Hawkins.",
                    runtimeMinutes: 49
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
            ]
        ]
    ]

    func trendingShows() async throws -> [Show] {
        Self.fixtureShows
    }

    func popularShows() async throws -> [Show] {
        Array(Self.fixtureShows.reversed())
    }

    func searchShows(query: String) async throws -> [Show] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return []
        }

        return Self.fixtureShows.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
                || $0.overview.localizedCaseInsensitiveContains(trimmed)
        }
    }

    func showDetail(showID: Int) async throws -> Show {
        guard let show = Self.fixtureShows.first(where: { $0.id == showID }) else {
            throw PreviewRepositoryError.showNotFound
        }

        return show
    }

    func watchProviders(showID _: Int) async throws -> [WatchProvider] {
        Self.fixtureProviders
    }

    func seasonEpisodes(showID: Int, seasonNumber: Int) async throws -> [ShowEpisode] {
        guard seasonNumber > 0 else {
            return []
        }

        return Self.fixtureSeasonEpisodes[showID]?[seasonNumber] ?? []
    }

    func clearCache() async {}
}
