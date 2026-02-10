import Foundation

struct Genre: Codable, Hashable, Identifiable {
    let id: Int
    let name: String
}

enum ShowStatus: Codable, Hashable {
    case ended
    case returningSeries
    case inProduction
    case planned
    case canceled
    case pilot
    case unknown(String)

    nonisolated init(tmdbValue: String?) {
        switch tmdbValue {
        case "Ended":
            self = .ended
        case "Returning Series":
            self = .returningSeries
        case "In Production":
            self = .inProduction
        case "Planned":
            self = .planned
        case "Canceled":
            self = .canceled
        case "Pilot":
            self = .pilot
        case let value?:
            self = .unknown(value)
        case nil:
            self = .unknown("Unknown")
        }
    }

    var displayName: String {
        switch self {
        case .ended:
            return "Ended"
        case .returningSeries:
            return "Returning"
        case .inProduction:
            return "In Production"
        case .planned:
            return "Planned"
        case .canceled:
            return "Canceled"
        case .pilot:
            return "Pilot"
        case let .unknown(raw):
            return raw
        }
    }
}

struct Show: Identifiable, Hashable, Codable {
    let id: Int
    let name: String
    let posterPath: String?
    let overview: String
    let genres: [Genre]
    let status: ShowStatus?
    let lastAirDate: Date?
    let nextEpisodeAirDate: Date?
    let airedEpisodeCount: Int?
    let voteAverage: Double?
    let voteCount: Int?

    nonisolated init(
        id: Int,
        name: String,
        posterPath: String?,
        overview: String,
        genres: [Genre],
        status: ShowStatus?,
        lastAirDate: Date?,
        nextEpisodeAirDate: Date?,
        airedEpisodeCount: Int?,
        voteAverage: Double? = nil,
        voteCount: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.posterPath = posterPath
        self.overview = overview
        self.genres = genres
        self.status = status
        self.lastAirDate = lastAirDate
        self.nextEpisodeAirDate = nextEpisodeAirDate
        self.airedEpisodeCount = airedEpisodeCount
        self.voteAverage = voteAverage
        self.voteCount = voteCount
    }

    var bingeableState: BingeableState {
        BingeableEvaluator.evaluate(show: self)
    }
}

struct WatchProvider: Identifiable, Hashable, Codable {
    let id: Int
    let name: String
    let logoPath: String?
}
