import Foundation
import SwiftData
import Testing
@testable import bingeable

struct LibraryViewModelTests {

    @Test("Library sections are status-first and follow sorting rules")
    @MainActor
    func librarySectionsAreOrderedAndSorted() async throws {
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        let tracked: [TrackedShow] = [
            makeTrackedShow(id: 11, name: "Ready New", updatedAt: base.addingTimeInterval(140)),
            makeTrackedShow(id: 10, name: "Ready Old", updatedAt: base.addingTimeInterval(20)),
            makeTrackedShow(id: 21, name: "Up Next Later", updatedAt: base.addingTimeInterval(30)),
            makeTrackedShow(id: 20, name: "Up Next Sooner", updatedAt: base.addingTimeInterval(40)),
            makeTrackedShow(id: 99, name: "Unknown", updatedAt: base.addingTimeInterval(10))
        ]

        let repository = MockShowRepository(detailsByID: [
            10: makeDetailShow(id: 10, name: "Ready Old", status: .ended, nextEpisodeAirDate: nil, airedCount: 14),
            11: makeDetailShow(id: 11, name: "Ready New", status: .ended, nextEpisodeAirDate: nil, airedCount: 8),
            20: makeDetailShow(id: 20, name: "Up Next Sooner", status: .returningSeries, nextEpisodeAirDate: base.addingTimeInterval(60 * 60 * 24 * 2), airedCount: 8),
            21: makeDetailShow(id: 21, name: "Up Next Later", status: .returningSeries, nextEpisodeAirDate: base.addingTimeInterval(60 * 60 * 24 * 6), airedCount: 8)
        ])

        let viewModel = LibraryViewModel()
        viewModel.load(tracked: tracked, repository: repository)
        await viewModel.waitForHydrationForTesting()

        #expect(viewModel.sections.map(\.bucket) == [.readyNow, .notYet, .unknown])
        #expect(viewModel.sections[0].items.map(\.id) == [11, 10])
        #expect(viewModel.sections[1].items.map(\.id) == [20, 21])
        #expect(viewModel.sections[2].items.map(\.id) == [99])
    }

    @Test("Library shelf filter narrows items across sections")
    @MainActor
    func libraryShelfFilterNarrowing() async throws {
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        let tracked: [TrackedShow] = [
            makeTrackedShow(id: 1, name: "Watching Ready", shelf: .watching, updatedAt: base.addingTimeInterval(10)),
            makeTrackedShow(id: 2, name: "Waiting Ready", shelf: .waiting, updatedAt: base.addingTimeInterval(9)),
            makeTrackedShow(id: 3, name: "Watching Unknown", shelf: .watching, updatedAt: base.addingTimeInterval(8))
        ]

        let repository = MockShowRepository(detailsByID: [
            1: makeDetailShow(id: 1, name: "Watching Ready", status: .ended, nextEpisodeAirDate: nil, airedCount: 10),
            2: makeDetailShow(id: 2, name: "Waiting Ready", status: .ended, nextEpisodeAirDate: nil, airedCount: 10)
        ])

        let viewModel = LibraryViewModel()
        viewModel.load(tracked: tracked, repository: repository)
        await viewModel.waitForHydrationForTesting()

        viewModel.shelfFilter = .watching
        await Task.yield()

        let allFilteredItems = viewModel.sections.flatMap(\.items)
        #expect(!allFilteredItems.isEmpty)
        #expect(allFilteredItems.allSatisfy { $0.shelf == .watching })
    }

    @Test("Library search is case-insensitive")
    @MainActor
    func librarySearchIsCaseInsensitive() async throws {
        let tracked: [TrackedShow] = [
            makeTrackedShow(id: 1, name: "Breaking Bad", updatedAt: .now),
            makeTrackedShow(id: 2, name: "The Office", updatedAt: .now.addingTimeInterval(-20))
        ]

        let repository = MockShowRepository(detailsByID: [
            1: makeDetailShow(id: 1, name: "Breaking Bad", status: .ended, nextEpisodeAirDate: nil, airedCount: 62),
            2: makeDetailShow(id: 2, name: "The Office", status: .ended, nextEpisodeAirDate: nil, airedCount: 201)
        ])

        let viewModel = LibraryViewModel()
        viewModel.load(tracked: tracked, repository: repository)
        await viewModel.waitForHydrationForTesting()

        viewModel.searchQuery = "office"
        await Task.yield()
        let filteredIDs = viewModel.sections.flatMap(\.items).map(\.id)

        #expect(filteredIDs == [2])
    }

    @Test("Library hydration failures remain in unknown bucket")
    @MainActor
    func libraryFallbackToUnknownOnHydrationFailure() async throws {
        let tracked = [
            makeTrackedShow(id: 404, name: "Not Found", updatedAt: .now)
        ]

        let repository = MockShowRepository(detailsByID: [:])

        let viewModel = LibraryViewModel()
        viewModel.load(tracked: tracked, repository: repository)
        await viewModel.waitForHydrationForTesting()

        #expect(viewModel.sections.map(\.bucket) == [.unknown])
        #expect(viewModel.sections[0].items.map(\.id) == [404])
        #expect(viewModel.hydrationErrorMessage != nil)
    }

    @Test("Library inline move and remove actions update persistence and summary")
    @MainActor
    func libraryInlineMoveAndRemove() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: TrackedShowEntity.self, configurations: configuration)
        let store = LibraryStore(context: container.mainContext)

        let first = makeDetailShow(id: 1, name: "First", status: .ended, nextEpisodeAirDate: nil, airedCount: 12)
        let second = makeDetailShow(id: 2, name: "Second", status: .ended, nextEpisodeAirDate: nil, airedCount: 6)

        store.upsert(show: first, shelf: .waiting)
        store.upsert(show: second, shelf: .waiting)

        let repository = MockShowRepository(detailsByID: [
            1: first,
            2: second
        ])

        let viewModel = LibraryViewModel()
        viewModel.load(tracked: store.allTrackedShows(), repository: repository)
        await viewModel.waitForHydrationForTesting()

        viewModel.move(showID: 1, to: .watching, using: store, repository: repository)
        await viewModel.waitForHydrationForTesting()

        #expect(store.shelf(for: 1) == .watching)
        #expect(viewModel.summary.watchingCount == 1)

        viewModel.remove(showID: 2, using: store, repository: repository)
        await viewModel.waitForHydrationForTesting()

        #expect(store.shelf(for: 2) == nil)
        #expect(viewModel.summary.totalCount == 1)
    }

    @Test("Library store isolates records by active auth scope")
    @MainActor
    func libraryStoreIsolatedByScope() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: TrackedShowEntity.self, configurations: configuration)
        let store = LibraryStore(context: container.mainContext)

        let show = makeDetailShow(id: 42, name: "Scoped Show", status: .ended, nextEpisodeAirDate: nil, airedCount: 10)

        store.setActiveScope("guest")
        store.upsert(show: show, shelf: .waiting)
        #expect(store.shelf(for: 42) == .waiting)

        store.setActiveScope("user@example.com")
        #expect(store.shelf(for: 42) == nil)

        store.upsert(show: show, shelf: .watching)
        #expect(store.shelf(for: 42) == .watching)

        store.setActiveScope("guest")
        #expect(store.shelf(for: 42) == .waiting)
        #expect(store.allTrackedShows().count == 1)

        store.setActiveScope("user@example.com")
        #expect(store.shelf(for: 42) == .watching)
        #expect(store.allTrackedShows().count == 1)
    }

    private func makeTrackedShow(
        id: Int,
        name: String,
        shelf: LibraryShelf = .waiting,
        updatedAt: Date
    ) -> TrackedShow {
        TrackedShow(
            id: id,
            shelf: shelf,
            addedAt: updatedAt.addingTimeInterval(-300),
            updatedAt: updatedAt,
            name: name,
            posterPath: nil,
            overview: "Overview"
        )
    }

    private func makeDetailShow(
        id: Int,
        name: String,
        status: ShowStatus,
        nextEpisodeAirDate: Date?,
        airedCount: Int?
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

    private actor MockShowRepository: ShowRepository {
        let detailsByID: [Int: Show]

        init(detailsByID: [Int: Show]) {
            self.detailsByID = detailsByID
        }

        func trendingShows() async throws -> [Show] {
            []
        }

        func popularShows() async throws -> [Show] {
            []
        }

        func searchShows(query _: String) async throws -> [Show] {
            []
        }

        func showDetail(showID: Int) async throws -> Show {
            guard let detail = detailsByID[showID] else {
                throw MockError.notFound
            }

            return detail
        }

        func watchProviders(showID _: Int) async throws -> [WatchProvider] {
            []
        }

        func clearCache() async {}
    }

    private enum MockError: Error {
        case notFound
    }
}
