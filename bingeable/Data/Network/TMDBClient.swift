import Foundation

enum TMDBError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case requestFailed(Int)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "TMDB API key is missing. Set TMDB_API_KEY in your scheme environment or TMDBApiKey in Info.plist."
        case .invalidResponse:
            return "Invalid response from TMDB."
        case let .requestFailed(statusCode):
            return "TMDB request failed with status code \(statusCode)."
        }
    }
}

actor TMDBClient {
    private let apiKey: String?
    private let baseURL: URL
    private let decoder: JSONDecoder
    private let session: URLSession

    init(apiKey: String?, baseURL: URL = AppConfiguration.tmdbBaseURL) {
        self.apiKey = apiKey
        self.baseURL = baseURL

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder

        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = AppConfiguration.makeURLCache()
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: configuration)
    }

    func trendingTV() async throws -> [TMDBShowSummaryDTO] {
        let response: TMDBListResponse = try await request(path: "/trending/tv/week")
        return response.results
    }

    func popularTV() async throws -> [TMDBShowSummaryDTO] {
        let response: TMDBListResponse = try await request(path: "/tv/popular")
        return response.results
    }

    func searchTV(query: String) async throws -> [TMDBShowSummaryDTO] {
        let response: TMDBListResponse = try await request(path: "/search/tv", queryItems: [
            URLQueryItem(name: "query", value: query)
        ])
        return response.results
    }

    func showDetail(id: Int) async throws -> TMDBShowDetailDTO {
        try await request(path: "/tv/\(id)")
    }

    func watchProviders(id: Int) async throws -> TMDBWatchProviderResponse {
        try await request(path: "/tv/\(id)/watch/providers")
    }

    func clearURLCache() {
        session.configuration.urlCache?.removeAllCachedResponses()
    }

    private func request<T: Decodable>(path: String, queryItems: [URLQueryItem] = []) async throws -> T {
        guard let apiKey, !apiKey.isEmpty else {
            throw TMDBError.missingAPIKey
        }

        let normalizedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let endpointURL = baseURL.appendingPathComponent(normalizedPath)

        var components = URLComponents(url: endpointURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "api_key", value: apiKey)] + queryItems

        guard let url = components?.url else {
            throw TMDBError.invalidResponse
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TMDBError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw TMDBError.requestFailed(httpResponse.statusCode)
        }

        return try decoder.decode(T.self, from: data)
    }
}
