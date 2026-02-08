import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var libraryStore: LibraryStore

    @State private var isClearing = false
    @State private var cacheStatusMessage: String?

    var body: some View {
        Form {
            Section("Account") {
                accountText

                if sessionManager.authState != .undetermined {
                    Button("Sign Out", role: .destructive) {
                        sessionManager.signOut()
                    }
                }
            }

            Section("Region") {
                Text(appContainer.regionCode)
            }

            Section("Data") {
                Button(isClearing ? "Clearing..." : "Clear Cache") {
                    clearCache()
                }
                .disabled(isClearing)

                if let cacheStatusMessage {
                    Text(cacheStatusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if !appContainer.hasTMDBAPIKey {
                    Text("TMDB API key not configured. App is using local fallback data.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
    }

    private var accountText: some View {
        switch sessionManager.authState {
        case .guest:
            return Text("Signed in as Guest")
        case let .signedIn(email):
            return Text("Signed in as \(email)")
        case .undetermined:
            return Text("Signed out")
        }
    }

    private func clearCache() {
        cacheStatusMessage = nil
        isClearing = true

        Task {
            await appContainer.showRepository.clearCache()
            await MainActor.run {
                isClearing = false
                cacheStatusMessage = "Cache cleared"
            }
        }
    }
}
