import SwiftData
import SwiftUI

@main
struct bingeableApp: App {
    @StateObject private var appContainer: AppContainer
    @StateObject private var libraryStore: LibraryStore

    private let modelContainer: ModelContainer

    init() {
        let container = Self.makeModelContainer()
        self.modelContainer = container

        let appContainer = AppContainer()
        let libraryStore = LibraryStore(context: container.mainContext)
        _appContainer = StateObject(wrappedValue: appContainer)
        _libraryStore = StateObject(wrappedValue: libraryStore)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appContainer)
                .environmentObject(appContainer.sessionManager)
                .environmentObject(libraryStore)
        }
        .modelContainer(modelContainer)
    }

    private static func makeModelContainer() -> ModelContainer {
        do {
            return try ModelContainer(for: TrackedShowEntity.self)
        } catch {
            // If migration fails, keep the app launchable by falling back to an in-memory store.
            NSLog("Failed to open persistent ModelContainer: \(error.localizedDescription)")
            let fallback = ModelConfiguration(isStoredInMemoryOnly: true)
            return try! ModelContainer(for: TrackedShowEntity.self, configurations: fallback)
        }
    }
}
