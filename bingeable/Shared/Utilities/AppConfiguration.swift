import Foundation

enum AppConfiguration {
    nonisolated static let isRunningInPreviewHost: Bool = {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCODE_RUNNING_FOR_PLAYGROUNDS"] == "1"
            || environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }()

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
    nonisolated static let discoverPreviewDataLoadingEnabled: Bool = {
#if DEBUG
        boolFlag(
            named: "DISCOVER_PREVIEW_DATA_LOADING",
            default: true
        )
#else
        return true
#endif
    }()
    nonisolated static let discoverPreviewUseFixtureRepository: Bool = {
#if DEBUG
        if isRunningInPreviewHost {
            return boolFlag(
                named: "DISCOVER_PREVIEW_USE_FIXTURE_REPOSITORY",
                default: true
            )
        }
#endif
        return false
    }()
    nonisolated static let discoverPreviewDetailHydrationEnabled: Bool = {
#if DEBUG
        if isRunningInPreviewHost {
            return boolFlag(
                named: "DISCOVER_PREVIEW_DETAIL_HYDRATION",
                default: false
            )
        }
#endif
        return true
    }()
    nonisolated static let discoverPreviewHeroEnabled: Bool = {
#if DEBUG
        if isRunningInPreviewHost {
            return boolFlag(
                named: "DISCOVER_PREVIEW_HERO",
                default: true
            )
        }
#endif
        return true
    }()
    nonisolated static let discoverPreviewHeroInteractiveEnabled: Bool = {
#if DEBUG
        if isRunningInPreviewHost {
            return boolFlag(
                named: "DISCOVER_PREVIEW_HERO_INTERACTIVE",
                default: false
            )
        }
#endif
        return true
    }()
    nonisolated static let discoverHeroAutoplayEnabled: Bool = {
#if DEBUG
        if isRunningInPreviewHost {
            return boolFlag(
                named: "DISCOVER_HERO_AUTOPLAY_IN_PREVIEW",
                default: false
            )
        }

        return boolFlag(
            named: "DISCOVER_HERO_AUTOPLAY",
            default: true
        )
#else
        return true
#endif
    }()
    nonisolated static let discoverHeroAutoplayIntervalSeconds: TimeInterval = {
#if DEBUG
        if isRunningInPreviewHost {
            return doubleFlag(
                named: "DISCOVER_HERO_AUTOPLAY_INTERVAL_PREVIEW_SECONDS",
                default: 14
            )
        }

        return doubleFlag(
            named: "DISCOVER_HERO_AUTOPLAY_INTERVAL_SECONDS",
            default: 6
        )
#else
        return 6
#endif
    }()
    nonisolated static let discoverHeroAutoplayIdleThresholdSeconds: TimeInterval = {
#if DEBUG
        if isRunningInPreviewHost {
            return doubleFlag(
                named: "DISCOVER_HERO_AUTOPLAY_IDLE_PREVIEW_SECONDS",
                default: 8
            )
        }

        return doubleFlag(
            named: "DISCOVER_HERO_AUTOPLAY_IDLE_SECONDS",
            default: 6
        )
#else
        return 6
#endif
    }()
    nonisolated static let discoverHeroAutoplayAnimationDurationSeconds: Double = {
#if DEBUG
        if isRunningInPreviewHost {
            return doubleFlag(
                named: "DISCOVER_HERO_AUTOPLAY_ANIMATION_PREVIEW_SECONDS",
                default: 1.1
            )
        }

        return doubleFlag(
            named: "DISCOVER_HERO_AUTOPLAY_ANIMATION_SECONDS",
            default: 0.95
        )
#else
        return 0.95
#endif
    }()
    nonisolated static let firebaseAuthUseEmulator: Bool = {
#if DEBUG
        boolFlag(named: "FIREBASE_AUTH_USE_EMULATOR", default: false)
#else
        return false
#endif
    }()
    nonisolated static let firebaseAuthEmulatorHost: String = {
#if DEBUG
        stringFlag(named: "FIREBASE_AUTH_EMULATOR_HOST", default: "127.0.0.1")
#else
        return "127.0.0.1"
#endif
    }()
    nonisolated static let firebaseAuthEmulatorPort: Int = {
#if DEBUG
        intFlag(named: "FIREBASE_AUTH_EMULATOR_PORT", default: 9099)
#else
        return 9099
#endif
    }()
    nonisolated static let firestoreUseEmulator: Bool = {
#if DEBUG
        boolFlag(named: "FIRESTORE_USE_EMULATOR", default: false)
#else
        return false
#endif
    }()
    nonisolated static let firestoreEmulatorHost: String = {
#if DEBUG
        stringFlag(named: "FIRESTORE_EMULATOR_HOST", default: "127.0.0.1")
#else
        return "127.0.0.1"
#endif
    }()
    nonisolated static let firestoreEmulatorPort: Int = {
#if DEBUG
        intFlag(named: "FIRESTORE_EMULATOR_PORT", default: 8080)
#else
        return 8080
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

    private nonisolated static func doubleFlag(named key: String, default defaultValue: Double) -> Double {
        guard let rawValue = ProcessInfo.processInfo.environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty,
              let parsed = Double(rawValue),
              parsed.isFinite,
              parsed > 0 else {
            return defaultValue
        }

        return parsed
    }

    private nonisolated static func intFlag(named key: String, default defaultValue: Int) -> Int {
        guard let rawValue = ProcessInfo.processInfo.environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty,
              let parsed = Int(rawValue),
              parsed > 0 else {
            return defaultValue
        }

        return parsed
    }

    private nonisolated static func stringFlag(named key: String, default defaultValue: String) -> String {
        guard let rawValue = ProcessInfo.processInfo.environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty else {
            return defaultValue
        }

        return rawValue
    }
}
