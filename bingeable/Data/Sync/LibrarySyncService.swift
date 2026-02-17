import Foundation

protocol LibrarySyncServicing {
    func fetchLibrary(for userID: String) async throws -> [TrackedShow]
    func upsert(_ trackedShow: TrackedShow, for userID: String) async throws
    func remove(showID: Int, for userID: String) async throws
}

final class NoopLibrarySyncService: LibrarySyncServicing {
    func fetchLibrary(for _: String) async throws -> [TrackedShow] {
        []
    }

    func upsert(_: TrackedShow, for _: String) async throws {}

    func remove(showID _: Int, for _: String) async throws {}
}

enum LibrarySyncServiceError: LocalizedError {
    case unavailable
    case invalidUserID

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Cloud sync is unavailable. Add FirebaseFirestore via Swift Package Manager."
        case .invalidUserID:
            return "Invalid user identifier for cloud sync."
        }
    }
}

#if canImport(FirebaseFirestore)
import FirebaseFirestore

final class FirestoreLibrarySyncService: LibrarySyncServicing {
    private let firestore: Firestore?

    init() {
        guard FirebaseBootstrap.isConfigured else {
            self.firestore = nil
            return
        }
        let firestore = Firestore.firestore()
        self.firestore = firestore

#if DEBUG
        if AppConfiguration.firestoreUseEmulator {
            firestore.useEmulator(
                withHost: AppConfiguration.firestoreEmulatorHost,
                port: AppConfiguration.firestoreEmulatorPort
            )
        }
#endif
    }

    func fetchLibrary(for userID: String) async throws -> [TrackedShow] {
        let normalizedUserID = try normalizedUserID(userID)
        _ = try resolvedFirestore()
        let snapshot = try await libraryCollection(for: normalizedUserID).getDocuments()

        return snapshot.documents
            .compactMap(mapTrackedShow(from:))
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func upsert(_ trackedShow: TrackedShow, for userID: String) async throws {
        let normalizedUserID = try normalizedUserID(userID)
        _ = try resolvedFirestore()
        let doc = libraryCollection(for: normalizedUserID).document(String(trackedShow.id))
        try await doc.setData(payload(from: trackedShow), merge: true)
    }

    func remove(showID: Int, for userID: String) async throws {
        let normalizedUserID = try normalizedUserID(userID)
        _ = try resolvedFirestore()
        let doc = libraryCollection(for: normalizedUserID).document(String(showID))
        try await doc.delete()
    }

    private func normalizedUserID(_ userID: String) throws -> String {
        let normalized = userID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            throw LibrarySyncServiceError.invalidUserID
        }
        return normalized
    }

    private func libraryCollection(for userID: String) -> CollectionReference {
        let firestore = self.firestore ?? Firestore.firestore()
        return firestore
            .collection("users")
            .document(userID)
            .collection("library")
    }

    private func resolvedFirestore() throws -> Firestore {
        guard let firestore else {
            throw LibrarySyncServiceError.unavailable
        }

        return firestore
    }

    private func payload(from trackedShow: TrackedShow) -> [String: Any] {
        [
            "showID": trackedShow.id,
            "shelf": trackedShow.shelf.rawValue,
            "addedAt": trackedShow.addedAt,
            "updatedAt": trackedShow.updatedAt,
            "name": trackedShow.name,
            "posterPath": trackedShow.posterPath as Any,
            "overview": trackedShow.overview
        ]
    }

    private func mapTrackedShow(from document: QueryDocumentSnapshot) -> TrackedShow? {
        let data = document.data()

        let showID: Int
        if let rawShowID = data["showID"] as? Int {
            showID = rawShowID
        } else if let parsedShowID = Int(document.documentID) {
            showID = parsedShowID
        } else {
            return nil
        }

        let shelfRaw = data["shelf"] as? String ?? LibraryShelf.waiting.rawValue
        let shelf = LibraryShelf(rawValue: shelfRaw) ?? .waiting

        let addedAt = dateValue(from: data["addedAt"]) ?? .now
        let updatedAt = dateValue(from: data["updatedAt"]) ?? addedAt

        let name = data["name"] as? String ?? "Unknown"
        let posterPath = data["posterPath"] as? String
        let overview = data["overview"] as? String ?? ""

        return TrackedShow(
            id: showID,
            shelf: shelf,
            addedAt: addedAt,
            updatedAt: updatedAt,
            name: name,
            posterPath: posterPath,
            overview: overview
        )
    }

    private func dateValue(from rawValue: Any?) -> Date? {
        if let timestamp = rawValue as? Timestamp {
            return timestamp.dateValue()
        }

        if let date = rawValue as? Date {
            return date
        }

        return nil
    }
}
#else
final class FirestoreLibrarySyncService: LibrarySyncServicing {
    func fetchLibrary(for _: String) async throws -> [TrackedShow] {
        throw LibrarySyncServiceError.unavailable
    }

    func upsert(_: TrackedShow, for _: String) async throws {
        throw LibrarySyncServiceError.unavailable
    }

    func remove(showID _: Int, for _: String) async throws {
        throw LibrarySyncServiceError.unavailable
    }
}
#endif
