import Foundation

enum LibraryShelf: String, Codable, CaseIterable, Hashable, Identifiable {
    case waiting
    case watching
    case finished

    var id: String { rawValue }

    var title: String {
        switch self {
        case .waiting:
            return "Waiting"
        case .watching:
            return "Watching"
        case .finished:
            return "Finished"
        }
    }

    var systemImage: String {
        switch self {
        case .waiting:
            return "clock"
        case .watching:
            return "play.circle"
        case .finished:
            return "checkmark.circle"
        }
    }
}
