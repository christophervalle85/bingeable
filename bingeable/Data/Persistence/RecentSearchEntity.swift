import Foundation
import SwiftData

@Model
final class RecentSearchEntity {
    @Attribute(.unique)
    var showID: Int
    var name: String
    var posterPath: String?
    var overview: String
    var updatedAt: Date

    init(
        showID: Int,
        name: String,
        posterPath: String?,
        overview: String,
        updatedAt: Date = .now
    ) {
        self.showID = showID
        self.name = name
        self.posterPath = posterPath
        self.overview = overview
        self.updatedAt = updatedAt
    }
}
