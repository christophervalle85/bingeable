import Foundation

nonisolated struct TMDBListResponse: Decodable {
    let results: [TMDBShowSummaryDTO]
}

nonisolated struct TMDBShowSummaryDTO: Decodable {
    let id: Int
    let name: String
    let posterPath: String?
    let overview: String
    let genreIds: [Int]?
    let voteAverage: Double?
    let voteCount: Int?
}

nonisolated struct TMDBGenreDTO: Decodable {
    let id: Int
    let name: String
}

nonisolated struct TMDBGenreListResponse: Decodable {
    let genres: [TMDBGenreDTO]
}

nonisolated struct TMDBEpisodeDTO: Decodable {
    let airDate: String?
    let episodeNumber: Int?
}

nonisolated struct TMDBSeasonDTO: Decodable {
    let seasonNumber: Int
    let name: String?
    let airDate: String?
    let episodeCount: Int?
}

nonisolated struct TMDBSeasonEpisodeDTO: Decodable {
    let episodeNumber: Int?
    let name: String?
    let airDate: String?
    let overview: String?
    let runtime: Int?
}

nonisolated struct TMDBSeasonDetailDTO: Decodable {
    let episodes: [TMDBSeasonEpisodeDTO]
}

nonisolated struct TMDBShowDetailDTO: Decodable {
    let id: Int
    let name: String
    let posterPath: String?
    let overview: String
    let genres: [TMDBGenreDTO]
    let status: String?
    let lastAirDate: String?
    let nextEpisodeToAir: TMDBEpisodeDTO?
    let lastEpisodeToAir: TMDBEpisodeDTO?
    let numberOfEpisodes: Int?
    let voteAverage: Double?
    let voteCount: Int?
    let seasons: [TMDBSeasonDTO]?
}

nonisolated struct TMDBWatchProviderResponse: Decodable {
    let results: [String: TMDBRegionProviders]
}

nonisolated struct TMDBRegionProviders: Decodable {
    let flatrate: [TMDBProviderDTO]?
}

nonisolated struct TMDBProviderDTO: Decodable {
    let providerId: Int
    let providerName: String
    let logoPath: String?
}
