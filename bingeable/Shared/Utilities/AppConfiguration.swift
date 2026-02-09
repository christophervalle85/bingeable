import Foundation

enum AppConfiguration {
    nonisolated static var tmdbAPIKey: String? {
        if let fromEnvironment = ProcessInfo.processInfo.environment["TMDB_API_KEY"], !fromEnvironment.isEmpty {
            return fromEnvironment
        }

        if let fromInfo = Bundle.main.object(forInfoDictionaryKey: "TMDBApiKey") as? String, !fromInfo.isEmpty {
            return fromInfo
        }

        return nil
    }

    nonisolated static let tmdbBaseURL = URL(string: "https://api.themoviedb.org/3")!
    nonisolated static let tmdbImageBaseURL = URL(string: "https://image.tmdb.org/t/p")!

    nonisolated static func makeURLCache() -> URLCache {
        URLCache(memoryCapacity: 50 * 1024 * 1024, diskCapacity: 250 * 1024 * 1024)
    }
}
