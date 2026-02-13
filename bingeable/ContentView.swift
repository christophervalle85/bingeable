import SwiftUI
import SwiftData
import Combine

struct ContentView: View {
    var body: some View {
        LaunchGateView()
    }
}

#Preview {
    ContentPreviewRoot()
}

@MainActor
private final class PreviewDependencies: ObservableObject {
    let appContainer: AppContainer
    let modelContainer: ModelContainer
    let libraryStore: LibraryStore
    let recentSearchStore: RecentSearchStore
    let profileSettingsStore: ProfileSettingsStore

    init() {
        self.appContainer = AppContainer()

        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        self.modelContainer = try! ModelContainer(
            for: TrackedShowEntity.self,
            RecentSearchEntity.self,
            configurations: config
        )
        self.libraryStore = LibraryStore(context: modelContainer.mainContext)
        self.recentSearchStore = RecentSearchStore(context: modelContainer.mainContext)
        self.profileSettingsStore = ProfileSettingsStore()
    }
}

private struct ContentPreviewRoot: View {
    @StateObject private var deps = PreviewDependencies()

    var body: some View {
        ContentView()
            .environmentObject(deps.appContainer)
            .environmentObject(deps.appContainer.sessionManager)
            .environmentObject(deps.libraryStore)
            .environmentObject(deps.recentSearchStore)
            .environmentObject(deps.profileSettingsStore)
            .modelContainer(deps.modelContainer)
    }
}
