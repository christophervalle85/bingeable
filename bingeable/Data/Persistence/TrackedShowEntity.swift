import Foundation
import SwiftData

@Model
final class TrackedShowEntity {
    @Attribute(.unique) var scopedShowID: String
    var showID: Int
    var scopeID: String
    var shelfRawValue: String
    var name: String
    var posterPath: String?
    var overview: String
    var addedAt: Date
    var updatedAt: Date

    init(
        showID: Int,
        scopeID: String = "guest",
        shelf: LibraryShelf,
        name: String,
        posterPath: String?,
        overview: String,
        addedAt: Date = .now,
        updatedAt: Date = .now
    ) {
        let normalizedScopeID = scopeID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "guest"
            : scopeID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.scopedShowID = Self.makeScopedShowID(scopeID: normalizedScopeID, showID: showID)
        self.showID = showID
        self.scopeID = normalizedScopeID
        self.shelfRawValue = shelf.rawValue
        self.name = name
        self.posterPath = posterPath
        self.overview = overview
        self.addedAt = addedAt
        self.updatedAt = updatedAt
    }

    static func makeScopedShowID(scopeID: String, showID: Int) -> String {
        "\(scopeID)#\(showID)"
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
