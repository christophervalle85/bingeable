import Foundation
import Testing
@testable import bingeable

struct bingeableTests {

    @Test("Ended shows are ready to binge")
    func endedShowIsReady() {
        let show = makeShow(status: .ended, airedCount: 10, nextEpisodeAirDate: nil)

        #expect(BingeableEvaluator.evaluate(show: show) == .ready)
    }

    @Test("No next episode and episodes aired is ready")
    func noNextEpisodeIsReadyWhenAiredExists() {
        let show = makeShow(status: .returningSeries, airedCount: 8, nextEpisodeAirDate: nil)

        #expect(BingeableEvaluator.evaluate(show: show) == .ready)
    }

    @Test("Next episode scheduled is not ready")
    func scheduledNextEpisodeIsNotReady() {
        let show = makeShow(status: .returningSeries, airedCount: 8, nextEpisodeAirDate: .now)

        #expect(BingeableEvaluator.evaluate(show: show) == .notYet)
    }

    @Test("Missing aired data is TBD")
    func missingAiredDataIsTBD() {
        let show = makeShow(status: .returningSeries, airedCount: nil, nextEpisodeAirDate: nil)

        #expect(BingeableEvaluator.evaluate(show: show) == .tbd)
    }

    @Test("Discover ready filter keeps only ready shows")
    @MainActor
    func discoverReadyFilterKeepsOnlyReadyShows() async throws {
        let readyShow = makeShow(id: 1, status: .ended, airedCount: 12, nextEpisodeAirDate: nil)
        let notReadyShow = makeShow(id: 2, status: .returningSeries, airedCount: 8, nextEpisodeAirDate: .now)
        let repository = MockShowRepository(
            trending: [readyShow, notReadyShow],
            popular: [notReadyShow, readyShow]
        )
        let viewModel = DiscoverViewModel()

        await viewModel.refresh(using: repository)

        #expect(viewModel.visibleTrending.map(\.id) == [readyShow.id, notReadyShow.id])
        #expect(viewModel.visiblePopular.map(\.id) == [notReadyShow.id, readyShow.id])

        viewModel.readyToBingeOnly = true

        #expect(viewModel.visibleTrending.map(\.id) == [readyShow.id])
        #expect(viewModel.visiblePopular.map(\.id) == [readyShow.id])
    }

    @Test("Discover active section selects the correct source list")
    @MainActor
    func discoverSectionSwitchesBetweenTrendingAndPopular() async throws {
        let trendingShow = makeShow(id: 11, name: "Trending One", status: .ended, airedCount: 12, nextEpisodeAirDate: nil)
        let popularShow = makeShow(id: 22, name: "Popular One", status: .ended, airedCount: 8, nextEpisodeAirDate: nil)
        let repository = MockShowRepository(trending: [trendingShow], popular: [popularShow])
        let viewModel = DiscoverViewModel()

        await viewModel.refresh(using: repository)

        viewModel.activeSection = .trending
        #expect(viewModel.visibleShows(inLibraryIDs: []).map(\.id) == [trendingShow.id])

        viewModel.activeSection = .popular
        #expect(viewModel.visibleShows(inLibraryIDs: []).map(\.id) == [popularShow.id])
    }

    @Test("Discover library chip filters by saved ids")
    @MainActor
    func discoverLibraryFilterKeepsOnlyTrackedShows() async throws {
        let first = makeShow(id: 1, name: "First", status: .ended, airedCount: 12, nextEpisodeAirDate: nil)
        let second = makeShow(id: 2, name: "Second", status: .ended, airedCount: 8, nextEpisodeAirDate: nil)
        let repository = MockShowRepository(trending: [first, second], popular: [])
        let viewModel = DiscoverViewModel()

        await viewModel.refresh(using: repository)
        viewModel.activeSection = .trending
        viewModel.inLibraryOnly = true

        #expect(viewModel.visibleShows(inLibraryIDs: [second.id]).map(\.id) == [second.id])
    }

    @Test("Discover alphabetical sort is deterministic")
    @MainActor
    func discoverSortAlphabeticalOrdersShowsByName() async throws {
        let zulu = makeShow(id: 1, name: "Zulu", status: .ended, airedCount: 4, nextEpisodeAirDate: nil)
        let alpha = makeShow(id: 2, name: "Alpha", status: .ended, airedCount: 6, nextEpisodeAirDate: nil)
        let beta = makeShow(id: 3, name: "Beta", status: .ended, airedCount: 9, nextEpisodeAirDate: nil)
        let repository = MockShowRepository(trending: [zulu, alpha, beta], popular: [])
        let viewModel = DiscoverViewModel()

        await viewModel.refresh(using: repository)
        viewModel.activeSection = .trending
        viewModel.sortMode = .alphabetical

        #expect(viewModel.visibleShows(inLibraryIDs: []).map(\.name) == ["Alpha", "Beta", "Zulu"])
    }

    @Test("Discover ready and library filters compose together")
    @MainActor
    func discoverComposedFiltersRequireBothConditions() async throws {
        let readyTracked = makeShow(id: 1, name: "ReadyTracked", status: .ended, airedCount: 12, nextEpisodeAirDate: nil)
        let readyUntracked = makeShow(id: 2, name: "ReadyUntracked", status: .ended, airedCount: 10, nextEpisodeAirDate: nil)
        let notReadyTracked = makeShow(id: 3, name: "NotReadyTracked", status: .returningSeries, airedCount: 8, nextEpisodeAirDate: .now)
        let repository = MockShowRepository(trending: [readyTracked, readyUntracked, notReadyTracked], popular: [])
        let viewModel = DiscoverViewModel()

        await viewModel.refresh(using: repository)
        viewModel.activeSection = .trending
        viewModel.readyToBingeOnly = true
        viewModel.inLibraryOnly = true

        #expect(viewModel.visibleShows(inLibraryIDs: [readyTracked.id, notReadyTracked.id]).map(\.id) == [readyTracked.id])
    }

    @Test("Discover exposes expected category sections")
    @MainActor
    func discoverCategorySectionsContainExpectedBuckets() async throws {
        let ready = makeShow(id: 1, name: "Ready", status: .ended, airedCount: 10, nextEpisodeAirDate: nil)
        let soon = makeShow(id: 2, name: "Soon", status: .returningSeries, airedCount: 8, nextEpisodeAirDate: Calendar.current.date(byAdding: .day, value: 5, to: .now))
        let repository = MockShowRepository(trending: [ready], popular: [soon])
        let viewModel = DiscoverViewModel()

        await viewModel.refresh(using: repository)

        #expect(viewModel.categorySections.map(\.id) == ["trending", "popular", "ready", "soon"])
        #expect(viewModel.readyToBingeShows.map(\.id) == [ready.id])
        #expect(viewModel.readySoonShows.map(\.id) == [soon.id])
    }

    @Test("Discover hero prioritizes ready shows")
    @MainActor
    func discoverHeroPrioritizesReadyBeforeSoon() async throws {
        let ready = makeShow(id: 10, name: "Ready Hero", status: .ended, airedCount: 12, nextEpisodeAirDate: nil)
        let soon = makeShow(id: 11, name: "Soon Hero", status: .returningSeries, airedCount: 8, nextEpisodeAirDate: Calendar.current.date(byAdding: .day, value: 3, to: .now))
        let repository = MockShowRepository(trending: [soon], popular: [ready])
        let viewModel = DiscoverViewModel()

        await viewModel.refresh(using: repository)

        #expect(viewModel.heroShow?.id == ready.id)
    }

    private func makeShow(
        id: Int = 1,
        name: String = "Sample Show",
        status: ShowStatus,
        airedCount: Int?,
        nextEpisodeAirDate: Date?
    ) -> Show {
        Show(
            id: id,
            name: name,
            posterPath: nil,
            overview: "Overview",
            genres: [],
            status: status,
            lastAirDate: nil,
            nextEpisodeAirDate: nextEpisodeAirDate,
            airedEpisodeCount: airedCount
        )
    }

    private struct MockShowRepository: ShowRepository {
        let trending: [Show]
        let popular: [Show]

        func trendingShows() async throws -> [Show] {
            trending
        }

        func popularShows() async throws -> [Show] {
            popular
        }

        func searchShows(query: String) async throws -> [Show] {
            []
        }

        func showDetail(showID: Int) async throws -> Show {
            throw TestError.unimplemented
        }

        func watchProviders(showID: Int) async throws -> [WatchProvider] {
            []
        }

        func clearCache() async {}
    }

    private enum TestError: Error {
        case unimplemented
    }
}
