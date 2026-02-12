import Foundation
import Combine

@MainActor
final class ShowDetailViewModel: ObservableObject {
    @Published var show: Show
    @Published var providers: [WatchProvider] = []
    @Published var selectedSeasonNumber: Int?
    @Published var seasonEpisodes: [ShowEpisode] = []
    @Published var isLoading = false
    @Published var isLoadingSeasonEpisodes = false
    @Published var errorMessage: String?
    @Published var seasonEpisodesErrorMessage: String?

    private var hasLoaded = false
    private var seasonEpisodesByNumber: [Int: [ShowEpisode]] = [:]

    init(seedShow: Show) {
        self.show = seedShow
    }

    func load(using repository: ShowRepository, force: Bool = false) async {
        guard !hasLoaded || force else {
            await hydrateInitialSeasonEpisodes(using: repository)
            return
        }

        if force {
            seasonEpisodesByNumber.removeAll()
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

        await hydrateInitialSeasonEpisodes(using: repository, force: force)
    }

    func selectSeason(_ seasonNumber: Int, using repository: ShowRepository) async {
        guard seasonNumber > 0 else {
            return
        }

        selectedSeasonNumber = seasonNumber
        await loadEpisodes(for: seasonNumber, using: repository)
    }

    private func hydrateInitialSeasonEpisodes(using repository: ShowRepository, force: Bool = false) async {
        let released = releasedSeasonNumbers(for: show)
        guard let firstReleased = released.first else {
            selectedSeasonNumber = nil
            seasonEpisodes = []
            seasonEpisodesErrorMessage = nil
            return
        }

        if selectedSeasonNumber == nil || !released.contains(selectedSeasonNumber ?? -1) {
            selectedSeasonNumber = firstReleased
        }

        if let selectedSeasonNumber {
            await loadEpisodes(for: selectedSeasonNumber, using: repository, force: force)
        }
    }

    private func loadEpisodes(for seasonNumber: Int, using repository: ShowRepository, force: Bool = false) async {
        if !force, let cached = seasonEpisodesByNumber[seasonNumber] {
            if selectedSeasonNumber == seasonNumber {
                seasonEpisodes = cached
                seasonEpisodesErrorMessage = nil
            }
            return
        }

        if selectedSeasonNumber == seasonNumber {
            isLoadingSeasonEpisodes = true
            seasonEpisodesErrorMessage = nil
        }

        defer {
            if selectedSeasonNumber == seasonNumber {
                isLoadingSeasonEpisodes = false
            }
        }

        do {
            let episodes = try await repository.seasonEpisodes(showID: show.id, seasonNumber: seasonNumber)
                .sorted { lhs, rhs in
                    lhs.episodeNumber < rhs.episodeNumber
                }
            seasonEpisodesByNumber[seasonNumber] = episodes

            if selectedSeasonNumber == seasonNumber {
                seasonEpisodes = episodes
            }
        } catch {
            if selectedSeasonNumber == seasonNumber {
                seasonEpisodes = []
                seasonEpisodesErrorMessage = error.localizedDescription
            }
        }
    }

    private func releasedSeasonNumbers(for show: Show) -> [Int] {
        let now = Date()
        return (show.seasons ?? [])
            .filter { $0.seasonNumber > 0 }
            .filter { season in
                if let airDate = season.airDate {
                    return airDate <= now
                }
                return (season.episodeCount ?? 0) > 0
            }
            .map(\.seasonNumber)
            .sorted()
    }
}
