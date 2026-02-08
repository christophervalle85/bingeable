import Foundation
import SwiftData

@Model
final class TrackedShowEntity {
    @Attribute(.unique) var showID: Int
    var shelfRawValue: String
    var name: String
    var posterPath: String?
    var overview: String
    var addedAt: Date
    var updatedAt: Date

    init(
        showID: Int,
        shelf: LibraryShelf,
        name: String,
        posterPath: String?,
        overview: String,
        addedAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.showID = showID
        self.shelfRawValue = shelf.rawValue
        self.name = name
        self.posterPath = posterPath
        self.overview = overview
        self.addedAt = addedAt
        self.updatedAt = updatedAt
    }

    var shelf: LibraryShelf {
        get {
            LibraryShelf(rawValue: shelfRawValue) ?? .waiting
        }
        set {
            shelfRawValue = newValue.rawValue
        }
    }
}
