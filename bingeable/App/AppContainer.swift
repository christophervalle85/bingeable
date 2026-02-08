import Foundation
import Combine
import SwiftUI

@MainActor
final class AppContainer: ObservableObject {
    let sessionManager: SessionManager
    let showRepository: TMDBShowRepository
    let regionCode: String
    let hasTMDBAPIKey: Bool

    init() {
        let regionProvider = DeviceRegionProvider()
        self.regionCode = regionProvider.regionCode

        self.sessionManager = SessionManager()

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
