import Foundation

enum BingeableState: String, Codable, Hashable {
    case ready
    case notYet
    case tbd

    var title: String {
        switch self {
        case .ready:
            return "Ready to Binge"
        case .notYet:
            return "Not Yet"
        case .tbd:
            return "TBD"
        }
    }

    var tintName: String {
        switch self {
        case .ready:
            return "green"
        case .notYet:
            return "orange"
        case .tbd:
            return "gray"
        }
    }
}
