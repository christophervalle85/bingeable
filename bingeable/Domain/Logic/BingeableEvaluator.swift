import Foundation

enum BingeableEvaluator {
    static func evaluate(show: Show) -> BingeableState {
        if show.status == .ended {
            return .ready
        }

        guard let airedEpisodeCount = show.airedEpisodeCount else {
            return .tbd
        }

        if show.nextEpisodeAirDate == nil, airedEpisodeCount > 0 {
            return .ready
        }

        if show.nextEpisodeAirDate != nil {
            return .notYet
        }

        return .tbd
    }
}
