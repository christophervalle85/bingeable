import SwiftData
import SwiftUI

@main
struct bingeableApp: App {
    @StateObject private var appContainer: AppContainer
    @StateObject private var libraryStore: LibraryStore
    @StateObject private var recentSearchStore: RecentSearchStore
    @StateObject private var profileSettingsStore: ProfileSettingsStore

    private let modelContainer: ModelContainer

    init() {
        FirebaseBootstrap.configureIfAvailable()

        let container = Self.makeModelContainer()
        self.modelContainer = container

        let appContainer = AppContainer()
        let libraryStore = LibraryStore(context: container.mainContext)
        let recentSearchStore = RecentSearchStore(context: container.mainContext)
        let profileSettingsStore = ProfileSettingsStore()
        let environment = ProcessInfo.processInfo.environment

        libraryStore.setActiveScope(appContainer.sessionManager.libraryScopeIdentifier)

        if environment["UI_TEST_RESET_LIBRARY"] == "1" {
            libraryStore.clearAll()
        }

        if environment["UI_TEST_RESET_RECENTS"] == "1" {
            recentSearchStore.clearAll()
        }

        if environment["UI_TEST_RESET_PROFILE"] == "1" {
            profileSettingsStore.clearAll()
        }

        if let rawSeedCount = environment["UI_TEST_LIBRARY_SEED_COUNT"],
           let seedCount = Int(rawSeedCount),
           seedCount > 0 {
            Self.seedLibraryForUITests(count: seedCount, store: libraryStore)
        }
        _appContainer = StateObject(wrappedValue: appContainer)
        _libraryStore = StateObject(wrappedValue: libraryStore)
        _recentSearchStore = StateObject(wrappedValue: recentSearchStore)
        _profileSettingsStore = StateObject(wrappedValue: profileSettingsStore)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appContainer)
                .environmentObject(appContainer.sessionManager)
                .environmentObject(libraryStore)
                .environmentObject(recentSearchStore)
                .environmentObject(profileSettingsStore)
        }
        .modelContainer(modelContainer)
    }

    private static func makeModelContainer() -> ModelContainer {
        do {
            return try ModelContainer(for: TrackedShowEntity.self, RecentSearchEntity.self)
        } catch {
            // If migration fails, keep the app launchable by falling back to an in-memory store.
            NSLog("Failed to open persistent ModelContainer: \(error.localizedDescription)")
            let fallback = ModelConfiguration(isStoredInMemoryOnly: true)
            return try! ModelContainer(
                for: TrackedShowEntity.self,
                RecentSearchEntity.self,
                configurations: fallback
            )
        }
    }

    private static func seedLibraryForUITests(count: Int, store: LibraryStore) {
        for index in 0..<count {
            let show = Show(
                id: 9_900_000 + index,
                name: "Seed Show \(index + 1)",
                posterPath: nil,
                overview: "Seeded show for UI tests.",
                genres: [],
                status: nil,
                lastAirDate: nil,
                nextEpisodeAirDate: nil,
                airedEpisodeCount: nil
            )

            // Alternate shelves so stats and inline move actions are exercised.
            let shelf: LibraryShelf
            switch index % 3 {
            case 0:
                shelf = .waiting
            case 1:
                shelf = .watching
            default:
                shelf = .finished
            }

            store.upsert(show: show, shelf: shelf)
        }
    }
}
