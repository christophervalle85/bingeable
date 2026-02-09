import Foundation
import Testing
@testable import bingeable

struct ProfileSettingsStoreTests {

    @Test("Profile settings persist and load per scope")
    @MainActor
    func profileSettingsRoundTripPerScope() {
        let defaults = isolatedDefaults()
        let store = ProfileSettingsStore(defaults: defaults)

        let signedScope = ProfileScopeKey(identifier: "person@example.com")
        let guestScope = ProfileScopeKey(identifier: "guest")

        store.save(
            settings: ProfileSettings(
                displayName: "Person",
                avatarStyle: .cinema,
                bio: "Drama fan",
                subscribedProviderIDs: [8, 337]
            ),
            scope: signedScope
        )

        store.save(
            settings: ProfileSettings(
                displayName: "Guest",
                avatarStyle: .sparkle,
                bio: "Just browsing",
                subscribedProviderIDs: [384]
            ),
            scope: guestScope
        )

        let signed = store.load(scope: signedScope)
        let guest = store.load(scope: guestScope)

        #expect(signed.displayName == "Person")
        #expect(signed.avatarStyle == .cinema)
        #expect(signed.subscribedProviderIDs == [8, 337])

        #expect(guest.displayName == "Guest")
        #expect(guest.avatarStyle == .sparkle)
        #expect(guest.subscribedProviderIDs == [384])
    }

    @Test("Corrupt settings payload falls back to defaults")
    @MainActor
    func corruptPayloadFallbacksToDefaults() {
        let defaults = isolatedDefaults()
        defaults.set(Data("not-json".utf8), forKey: "profile.settings.byScope.v1")

        let store = ProfileSettingsStore(defaults: defaults)
        let scope = ProfileScopeKey(identifier: "guest")

        let loaded = store.load(scope: scope)

        #expect(loaded == .defaults(for: .guest))
    }

    @Test("Unknown providers are pruned during normalization")
    @MainActor
    func providerPruning() {
        let defaults = isolatedDefaults()
        let store = ProfileSettingsStore(defaults: defaults)
        let scope = ProfileScopeKey(identifier: "guest")

        store.save(
            settings: ProfileSettings(
                displayName: "Guest",
                avatarStyle: .classic,
                bio: "",
                subscribedProviderIDs: [8, 9999]
            ),
            scope: scope
        )

        let loaded = store.load(scope: scope)

        #expect(loaded.subscribedProviderIDs == [8])
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "ProfileSettingsStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
