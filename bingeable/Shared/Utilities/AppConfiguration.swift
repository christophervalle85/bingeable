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
    nonisolated static let discoverHeroAutoplayEnabled: Bool = {
#if DEBUG
        return boolFlag(
            named: "DISCOVER_HERO_AUTOPLAY",
            default: true
        )
#else
        return true
#endif
    }()

    nonisolated static func makeURLCache() -> URLCache {
        URLCache(memoryCapacity: 50 * 1024 * 1024, diskCapacity: 250 * 1024 * 1024)
    }

    private nonisolated static func boolFlag(named key: String, default defaultValue: Bool) -> Bool {
        guard let rawValue = ProcessInfo.processInfo.environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty else {
            return defaultValue
        }

        switch rawValue.lowercased() {
        case "1", "true", "yes", "on":
            return true
        case "0", "false", "no", "off":
            return false
        default:
            return defaultValue
        }
    }
}
