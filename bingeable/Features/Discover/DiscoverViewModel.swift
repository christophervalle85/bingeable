import Foundation
import Combine

@MainActor
final class DiscoverViewModel: ObservableObject {
    @Published var trending: [Show] = []
    @Published var popular: [Show] = []
    @Published var isLoading = false
    @Published var readyToBingeOnly = false
    @Published var errorMessage: String?

    private var hasLoaded = false

    var visibleTrending: [Show] {
        filtered(trending)
    }

    var visiblePopular: [Show] {
        filtered(popular)
    }

    func load(using repository: ShowRepository, force: Bool = false) async {
        guard !hasLoaded || force else {
            return
        }

        await refresh(using: repository)
    }

    func refresh(using repository: ShowRepository) async {
        isLoading = true
        errorMessage = nil

        do {
            async let trendingTask = repository.trendingShows()
            async let popularTask = repository.popularShows()
            let (trending, popular) = try await (trendingTask, popularTask)

            self.trending = trending
            self.popular = popular
            hasLoaded = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func filtered(_ shows: [Show]) -> [Show] {
        guard readyToBingeOnly else {
            return shows
        }

        return shows.filter { $0.bingeableState == .ready }
    }
}
