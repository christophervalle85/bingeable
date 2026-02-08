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

    private func makeShow(status: ShowStatus, airedCount: Int?, nextEpisodeAirDate: Date?) -> Show {
        Show(
            id: 1,
            name: "Sample Show",
            posterPath: nil,
            overview: "Overview",
            genres: [],
            status: status,
            lastAirDate: nil,
            nextEpisodeAirDate: nextEpisodeAirDate,
            airedEpisodeCount: airedCount
        )
    }
}
