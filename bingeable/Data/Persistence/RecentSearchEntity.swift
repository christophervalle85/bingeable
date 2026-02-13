import Foundation
import SwiftData

@Model
final class RecentSearchEntity {
    var query: String
    var displayQuery: String
    var updatedAt: Date

    init(
        query: String,
        displayQuery: String,
        updatedAt: Date = .now
    ) {
        self.query = query
        self.displayQuery = displayQuery
        self.updatedAt = updatedAt
    }
}
