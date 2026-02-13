import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var libraryStore: LibraryStore

    var body: some View {
        TabView {
            NavigationStack {
                DiscoverView()
            }
            .tabItem {
                Label("Discover", systemImage: "sparkles.tv")
            }

            NavigationStack {
                SearchView()
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }

            NavigationStack {
                LibraryView()
            }
            .tabItem {
                Label("Library", systemImage: "books.vertical")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle")
            }
        }
        .onAppear {
            libraryStore.setActiveScope(sessionManager.libraryScopeIdentifier)
        }
        .onChange(of: sessionManager.authState) { _, _ in
            libraryStore.setActiveScope(sessionManager.libraryScopeIdentifier)
        }
    }
}
