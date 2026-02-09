import Foundation
import Combine

struct ProfileProviderOption: Identifiable, Hashable {
    let id: Int
    let name: String
    let symbolName: String

    static let curatedOptions: [ProfileProviderOption] = [
        ProfileProviderOption(id: 8, name: "Netflix", symbolName: "n.circle.fill"),
        ProfileProviderOption(id: 15, name: "Hulu", symbolName: "h.circle.fill"),
        ProfileProviderOption(id: 384, name: "Max", symbolName: "m.circle.fill"),
        ProfileProviderOption(id: 9, name: "Prime Video", symbolName: "p.circle.fill"),
        ProfileProviderOption(id: 350, name: "Apple TV+", symbolName: "apple.logo"),
        ProfileProviderOption(id: 337, name: "Disney+", symbolName: "d.circle.fill"),
        ProfileProviderOption(id: 386, name: "Peacock", symbolName: "bird.fill"),
        ProfileProviderOption(id: 531, name: "Paramount+", symbolName: "mountain.2.fill")
    ]
}

enum ProfileScopeKey: Hashable {
    case signedIn(String)
    case guest
    case signedOut

    init(identifier: String) {
        switch identifier {
        case "guest":
            self = .guest
        case "signed_out":
            self = .signedOut
        default:
            self = .signedIn(identifier)
        }
    }

    var storageKey: String {
        switch self {
        case let .signedIn(email):
            return "signed_in:\(email)"
        case .guest:
            return "guest"
        case .signedOut:
            return "signed_out"
        }
    }

    var defaultDisplayName: String {
        switch self {
        case let .signedIn(email):
            return email.split(separator: "@").first.map(String.init) ?? "Viewer"
        case .guest:
            return "Guest"
        case .signedOut:
            return "Viewer"
        }
    }
}

enum ProfileAvatarStyle: String, Codable, CaseIterable, Identifiable {
    case classic
    case cinema
    case sparkle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic:
            return "Classic"
        case .cinema:
            return "Cinema"
        case .sparkle:
            return "Sparkle"
        }
    }

    var symbolName: String {
        switch self {
        case .classic:
            return "person.crop.circle.fill"
        case .cinema:
            return "film.circle.fill"
        case .sparkle:
            return "sparkles"
        }
    }
}

struct ProfileSettings: Codable, Equatable {
    var displayName: String
    var avatarStyle: ProfileAvatarStyle
    var bio: String
    var subscribedProviderIDs: Set<Int>

    static func defaults(for scope: ProfileScopeKey) -> ProfileSettings {
        ProfileSettings(
            displayName: scope.defaultDisplayName,
            avatarStyle: .classic,
            bio: "",
            subscribedProviderIDs: []
        )
    }
}

@MainActor
final class ProfileSettingsStore: ObservableObject {
    @Published private(set) var currentSettings: ProfileSettings = .defaults(for: .guest)

    private let defaults: UserDefaults

    private enum Keys {
        static let settingsByScope = "profile.settings.byScope.v1"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(scope: ProfileScopeKey) -> ProfileSettings {
        var byScope = loadSettingsByScope()
        let loaded = byScope[scope.storageKey] ?? ProfileSettings.defaults(for: scope)
        let normalized = normalizedSettings(loaded, for: scope)

        if byScope[scope.storageKey] != normalized {
            byScope[scope.storageKey] = normalized
            persist(byScope)
        }

        currentSettings = normalized
        return normalized
    }

    func save(settings: ProfileSettings, scope: ProfileScopeKey) {
        var byScope = loadSettingsByScope()
        byScope[scope.storageKey] = normalizedSettings(settings, for: scope)
        persist(byScope)
        currentSettings = byScope[scope.storageKey] ?? ProfileSettings.defaults(for: scope)
    }

    func reset(scope: ProfileScopeKey) {
        var byScope = loadSettingsByScope()
        byScope.removeValue(forKey: scope.storageKey)
        persist(byScope)
        currentSettings = ProfileSettings.defaults(for: scope)
    }

    func clearAll() {
        defaults.removeObject(forKey: Keys.settingsByScope)
        currentSettings = .defaults(for: .guest)
    }

    private func normalizedSettings(_ settings: ProfileSettings, for scope: ProfileScopeKey) -> ProfileSettings {
        let allowedIDs = Set(ProfileProviderOption.curatedOptions.map(\.id))
        let selectedIDs = settings.subscribedProviderIDs.intersection(allowedIDs)
        let trimmedDisplayName = settings.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = trimmedDisplayName.isEmpty ? scope.defaultDisplayName : trimmedDisplayName
        let bio = settings.bio.trimmingCharacters(in: .whitespacesAndNewlines)

        return ProfileSettings(
            displayName: displayName,
            avatarStyle: settings.avatarStyle,
            bio: bio,
            subscribedProviderIDs: selectedIDs
        )
    }

    private func loadSettingsByScope() -> [String: ProfileSettings] {
        guard let data = defaults.data(forKey: Keys.settingsByScope) else {
            return [:]
        }

        guard let decoded = try? JSONDecoder().decode([String: ProfileSettings].self, from: data) else {
            defaults.removeObject(forKey: Keys.settingsByScope)
            return [:]
        }

        return decoded
    }

    private func persist(_ byScope: [String: ProfileSettings]) {
        if let encoded = try? JSONEncoder().encode(byScope) {
            defaults.set(encoded, forKey: Keys.settingsByScope)
        }
    }
}
