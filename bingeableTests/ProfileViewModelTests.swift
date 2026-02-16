import Foundation
import Testing
@testable import bingeable

struct ProfileViewModelTests {

    @Test("Dirty tracking updates when profile fields change")
    @MainActor
    func dirtyTracking() {
        let defaults = isolatedDefaults()
        let sessionManager = SessionManager(defaults: defaults)
        sessionManager.continueAsGuest()
        let store = ProfileSettingsStore(defaults: defaults)
        let viewModel = ProfileViewModel()

        viewModel.bind(sessionManager: sessionManager, store: store)
        viewModel.loadForCurrentScope()

        #expect(viewModel.isDirty == false)

        viewModel.displayName = "Updated Name"
        #expect(viewModel.isDirty == true)

        viewModel.resetToSaved()
        #expect(viewModel.isDirty == false)
    }

    @Test("Save normalizes display name and bio")
    @MainActor
    func saveNormalization() {
        let defaults = isolatedDefaults()
        let sessionManager = SessionManager(defaults: defaults)
        sessionManager.continueAsGuest()
        let store = ProfileSettingsStore(defaults: defaults)
        let viewModel = ProfileViewModel()

        viewModel.bind(sessionManager: sessionManager, store: store)
        viewModel.loadForCurrentScope()

        viewModel.displayName = "   "
        viewModel.bio = String(repeating: "A", count: 220)
        viewModel.toggleProvider(8)
        viewModel.toggleProvider(9999)

        viewModel.save()

        let loaded = store.load(scope: .guest)
        #expect(loaded.displayName == "Guest")
        #expect(loaded.bio.count == 160)
        #expect(loaded.subscribedProviderIDs == [8])
    }

    @Test("Scope switches load per-account settings")
    @MainActor
    func scopeSwitchReload() async throws {
        let defaults = isolatedDefaults()
        let authAdapter = MockFirebaseAuthAdapter()
        let sessionManager = SessionManager(defaults: defaults, authAdapter: authAdapter)
        sessionManager.continueAsGuest()

        let store = ProfileSettingsStore(defaults: defaults)
        store.save(
            settings: ProfileSettings(displayName: "Guest User", avatarStyle: .classic, bio: "", subscribedProviderIDs: [8]),
            scope: .guest
        )

        let viewModel = ProfileViewModel()
        viewModel.bind(sessionManager: sessionManager, store: store)
        viewModel.loadForCurrentScope()

        #expect(viewModel.displayName == "Guest User")

        try await sessionManager.signUp(email: "tester@example.com", password: "123456")
        await Task.yield()
        viewModel.handleAuthStateChange()

        #expect(viewModel.activeScope == ProfileScopeKey.signedIn("tester@example.com"))
        #expect(viewModel.displayName == "tester")
    }

    @Test("Selected providers are derived from selected IDs")
    @MainActor
    func selectedProvidersDerivation() {
        let defaults = isolatedDefaults()
        let sessionManager = SessionManager(defaults: defaults)
        sessionManager.continueAsGuest()
        let store = ProfileSettingsStore(defaults: defaults)

        let viewModel = ProfileViewModel()
        viewModel.bind(sessionManager: sessionManager, store: store)
        viewModel.loadForCurrentScope()

        viewModel.toggleProvider(8)
        viewModel.toggleProvider(337)

        let names = Set(viewModel.selectedProviders.map(\.name))
        #expect(names == Set(["Netflix", "Disney+"]))
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "ProfileViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private final class MockFirebaseAuthAdapter: FirebaseAuthAdapting {
        private var listeners: [UUID: @Sendable (AuthSessionUser?) -> Void] = [:]
        private var current: AuthSessionUser?

        func currentUser() -> AuthSessionUser? {
            current
        }

        func listenAuthState(_ handler: @escaping @Sendable (AuthSessionUser?) -> Void) -> AuthStateListenerHandle {
            let id = UUID()
            listeners[id] = handler
            handler(current)
            return AuthStateListenerHandle { [weak self] in
                self?.listeners[id] = nil
            }
        }

        func signIn(email: String, password _: String) async throws {
            let uid = "uid_\(email.lowercased())"
            current = AuthSessionUser(uid: uid, email: email.lowercased())
            notify()
        }

        func signUp(email: String, password _: String) async throws {
            let uid = "uid_\(email.lowercased())"
            current = AuthSessionUser(uid: uid, email: email.lowercased())
            notify()
        }

        func signOut() throws {
            current = nil
            notify()
        }

        private func notify() {
            for listener in listeners.values {
                listener(current)
            }
        }
    }
}
