import Foundation
import Combine

@MainActor
final class ShowDetailViewModel: ObservableObject {
    @Published var show: Show
    @Published var providers: [WatchProvider] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var hasLoaded = false

    init(seedShow: Show) {
        self.show = seedShow
    }

    func load(using repository: ShowRepository, force: Bool = false) async {
        guard !hasLoaded || force else {
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            show = try await repository.showDetail(showID: show.id)
        } catch {
            errorMessage = error.localizedDescription
        }

        do {
            providers = try await repository.watchProviders(showID: show.id)
        } catch {
            if errorMessage == nil {
                errorMessage = error.localizedDescription
            }
        }

        hasLoaded = true
        isLoading = false
    }
}
