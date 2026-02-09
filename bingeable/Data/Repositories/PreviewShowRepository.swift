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
            airedEpisodeCount: 62
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
            airedEpisodeCount: 201
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
            airedEpisodeCount: 18
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
            airedEpisodeCount: 94
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
            airedEpisodeCount: 34
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
            airedEpisodeCount: 18
        )
    ]

    private nonisolated static let fixtureProviders: [WatchProvider] = [
        WatchProvider(id: 8, name: "Netflix", logoPath: nil),
        WatchProvider(id: 337, name: "Disney Plus", logoPath: nil),
        WatchProvider(id: 384, name: "HBO Max", logoPath: nil)
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

    func clearCache() async {}
}
