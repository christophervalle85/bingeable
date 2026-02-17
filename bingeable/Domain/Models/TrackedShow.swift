import Foundation

struct TrackedShow: Identifiable, Hashable, Sendable {
    let id: Int
    var shelf: LibraryShelf
    var addedAt: Date
    var updatedAt: Date
    var name: String
    var posterPath: String?
    var overview: String

    var asSeedShow: Show {
        Show(
            id: id,
            name: name,
            posterPath: posterPath,
            overview: overview,
            genres: [],
            status: nil,
            lastAirDate: nil,
            nextEpisodeAirDate: nil,
            airedEpisodeCount: nil
        )
    }
}
