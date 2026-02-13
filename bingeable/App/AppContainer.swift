import Foundation
import Combine
import SwiftUI

@MainActor
final class AppContainer: ObservableObject {
    let sessionManager: SessionManager
    let showRepository: any ShowRepository
    let regionCode: String
    let hasTMDBAPIKey: Bool

    init() {
        let regionProvider = DeviceRegionProvider()
        self.regionCode = regionProvider.regionCode

        self.sessionManager = SessionManager()
        let environment = ProcessInfo.processInfo.environment
        let useFixtureRepositoryForUITests = environment["UI_TEST_USE_FIXTURE_REPOSITORY"] == "1"

        if useFixtureRepositoryForUITests
            || (AppConfiguration.isRunningInPreviewHost && AppConfiguration.discoverPreviewUseFixtureRepository) {
            self.showRepository = PreviewShowRepository()
            self.hasTMDBAPIKey = false
        } else {
            let detailCache = ShowDetailCache()
            let client = TMDBClient(apiKey: AppConfiguration.tmdbAPIKey)
            self.showRepository = TMDBShowRepository(
                client: client,
                detailCache: detailCache,
                regionProvider: regionProvider
            )
            self.hasTMDBAPIKey = AppConfiguration.tmdbAPIKey?.isEmpty == false
        }
    }
}
