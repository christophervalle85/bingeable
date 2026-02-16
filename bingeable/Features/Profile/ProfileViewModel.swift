import Foundation
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var displayName: String = "" {
        didSet { updateDirtyState() }
    }
    @Published var bio: String = "" {
        didSet { updateDirtyState() }
    }
    @Published var avatarStyle: ProfileAvatarStyle = .classic {
        didSet { updateDirtyState() }
    }
    @Published private(set) var selectedProviderIDs: Set<Int> = [] {
        didSet { updateDirtyState() }
    }

    @Published private(set) var isDirty = false
    @Published private(set) var activeScope: ProfileScopeKey = .guest
    @Published var showDiscardChangesConfirmation = false

    private var pendingScope: ProfileScopeKey?
    private var baselineSettings: ProfileSettings = .defaults(for: .guest)
    private weak var sessionManager: SessionManager?
    private var store: ProfileSettingsStore?

    let providerOptions = ProfileProviderOption.curatedOptions

    private let displayNameMaxLength = 32
    private let bioMaxLength = 160

    func bind(sessionManager: SessionManager, store: ProfileSettingsStore) {
        self.sessionManager = sessionManager
        self.store = store

        if displayName.isEmpty && bio.isEmpty && selectedProviderIDs.isEmpty {
            loadForCurrentScope()
        }
    }

    func loadForCurrentScope() {
        guard let sessionManager, let store else { return }

        let scope = ProfileScopeKey(identifier: sessionManager.profileScopeIdentifier)
        let loaded = store.load(scope: scope)
        applyLoadedSettings(loaded, scope: scope)
    }

    func handleAuthStateChange() {
        guard let sessionManager else { return }

        let nextScope = ProfileScopeKey(identifier: sessionManager.profileScopeIdentifier)
        guard nextScope != activeScope else { return }

        guard isDirty else {
            switchScope(to: nextScope)
            return
        }

        pendingScope = nextScope
        showDiscardChangesConfirmation = true
    }

    func confirmDiscardAndSwitchScope() {
        guard let pendingScope else {
            showDiscardChangesConfirmation = false
            return
        }

        showDiscardChangesConfirmation = false
        self.pendingScope = nil
        switchScope(to: pendingScope)
    }

    func cancelScopeChange() {
        pendingScope = nil
        showDiscardChangesConfirmation = false
    }

    func toggleProvider(_ providerID: Int) {
        if selectedProviderIDs.contains(providerID) {
            selectedProviderIDs.remove(providerID)
        } else {
            selectedProviderIDs.insert(providerID)
        }
    }

    func save() {
        guard let store else { return }

        let normalized = normalizedCurrentSettings()
        store.save(settings: normalized, scope: activeScope)
        baselineSettings = normalized
        displayName = normalized.displayName
        bio = normalized.bio
        avatarStyle = normalized.avatarStyle
        selectedProviderIDs = normalized.subscribedProviderIDs
        isDirty = false
    }

    func saveIfNeeded() {
        if isDirty {
            save()
        }
    }

    func resetToSaved() {
        applyLoadedSettings(baselineSettings, scope: activeScope)
    }

    var selectedProviders: [ProfileProviderOption] {
        providerOptions.filter { selectedProviderIDs.contains($0.id) }
    }

    var accountBadgeText: String {
        guard let sessionManager else {
            return "Guest"
        }

        switch sessionManager.authState {
        case .guestLocal:
            return "Guest"
        case let .signedIn(_, email):
            return email ?? "Signed in"
        case .signedOut:
            return "Signed out"
        }
    }

    var displayNameRemainingCount: Int {
        max(0, displayNameMaxLength - displayName.count)
    }

    var bioRemainingCount: Int {
        max(0, bioMaxLength - bio.count)
    }

    private func switchScope(to scope: ProfileScopeKey) {
        guard let store else { return }
        let loaded = store.load(scope: scope)
        applyLoadedSettings(loaded, scope: scope)
    }

    private func applyLoadedSettings(_ settings: ProfileSettings, scope: ProfileScopeKey) {
        activeScope = scope
        baselineSettings = settings
        displayName = settings.displayName
        bio = settings.bio
        avatarStyle = settings.avatarStyle
        selectedProviderIDs = settings.subscribedProviderIDs
        isDirty = false
    }

    private func normalizedCurrentSettings() -> ProfileSettings {
        let truncatedName = String(displayName.prefix(displayNameMaxLength))
        let trimmedName = truncatedName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedName = trimmedName.isEmpty ? activeScope.defaultDisplayName : trimmedName

        let truncatedBio = String(bio.prefix(bioMaxLength))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let allowedIDs = Set(providerOptions.map(\.id))

        return ProfileSettings(
            displayName: normalizedName,
            avatarStyle: avatarStyle,
            bio: truncatedBio,
            subscribedProviderIDs: selectedProviderIDs.intersection(allowedIDs)
        )
    }

    private func updateDirtyState() {
        isDirty = normalizedCurrentSettings() != baselineSettings
    }
}
