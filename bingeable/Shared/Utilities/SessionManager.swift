import Foundation
import Combine
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

@MainActor
final class SessionManager: ObservableObject {
    enum AuthState: Equatable {
        case signedOut
        case guestLocal
        case signedIn(uid: String, email: String?)
    }

    enum AuthError: LocalizedError {
        case invalidEmail
        case invalidPassword
        case emailAlreadyInUse
        case accountNotFound
        case wrongPassword
        case backendUnavailable
        case unknown

        var errorDescription: String? {
            switch self {
            case .invalidEmail:
                return "Enter a valid email address."
            case .invalidPassword:
                return "Password must have at least 6 characters."
            case .emailAlreadyInUse:
                return "An account already exists for that email."
            case .accountNotFound:
                return "No account found for that email."
            case .wrongPassword:
                return "The password is incorrect."
            case .backendUnavailable:
                return "Authentication service is unavailable."
            case .unknown:
                return "Authentication failed. Please try again."
            }
        }
    }

    @Published private(set) var authState: AuthState = .signedOut

    var profileScopeIdentifier: String {
        switch authState {
        case let .signedIn(uid, email):
            return email ?? uid
        case .guestLocal:
            return "guest"
        case .signedOut:
            return "signed_out"
        }
    }

    var libraryScopeIdentifier: String {
        switch authState {
        case let .signedIn(uid, _):
            return uid
        case .guestLocal, .signedOut:
            return "guest"
        }
    }

    private let defaults: UserDefaults
    private let authAdapter: any FirebaseAuthAdapting
    private var authStateListener: AuthStateListenerHandle?
    private var remoteUser: AuthSessionUser?
    private var isGuestLocalEnabled: Bool

    private enum Keys {
        static let guestLocalEnabled = "session.guestLocal.enabled"
    }

    init(
        defaults: UserDefaults = .standard,
        authAdapter: (any FirebaseAuthAdapting)? = nil
    ) {
        self.defaults = defaults
        if let authAdapter {
            self.authAdapter = authAdapter
        } else if AppConfiguration.isRunningInPreviewHost || AppConfiguration.isRunningUnderXCTest {
            self.authAdapter = DisabledFirebaseAuthAdapter()
        } else {
            self.authAdapter = FirebaseAuthAdapter()
        }
        self.isGuestLocalEnabled = defaults.bool(forKey: Keys.guestLocalEnabled)
        self.authState = isGuestLocalEnabled ? .guestLocal : .signedOut
        attachAuthListener()
    }

    func enterGuestLocal() {
        isGuestLocalEnabled = true
        defaults.set(true, forKey: Keys.guestLocalEnabled)
        authState = .guestLocal
    }

    func continueAsGuest() {
        enterGuestLocal()
    }

    func exitGuestLocal() {
        isGuestLocalEnabled = false
        defaults.set(false, forKey: Keys.guestLocalEnabled)
        updateAuthStateFromSources()
    }

    func signIn(email: String, password: String) async throws {
        let normalizedEmail = try validateEmail(email)
        let password = try validatePassword(password)
        isGuestLocalEnabled = false
        defaults.set(false, forKey: Keys.guestLocalEnabled)

        do {
            try await authAdapter.signIn(email: normalizedEmail, password: password)
        } catch {
            throw mapAuthError(error)
        }
    }

    func signUp(email: String, password: String) async throws {
        let normalizedEmail = try validateEmail(email)
        let password = try validatePassword(password)
        isGuestLocalEnabled = false
        defaults.set(false, forKey: Keys.guestLocalEnabled)

        do {
            try await authAdapter.signUp(email: normalizedEmail, password: password)
        } catch {
            throw mapAuthError(error)
        }
    }

    func signOut() throws {
        if authState == .guestLocal {
            exitGuestLocal()
            return
        }

        guard case .signedIn = authState else {
            return
        }

        do {
            try authAdapter.signOut()
        } catch {
            throw mapAuthError(error)
        }
    }

    private func attachAuthListener() {
        authStateListener?.cancel()
        authStateListener = authAdapter.listenAuthState { [weak self] user in
            guard let self else { return }

            Task { @MainActor in
                self.handleRemoteAuthStateChange(user)
            }
        }

        handleRemoteAuthStateChange(authAdapter.currentUser())
    }

    private func handleRemoteAuthStateChange(_ user: AuthSessionUser?) {
        remoteUser = user

        if user != nil, isGuestLocalEnabled {
            isGuestLocalEnabled = false
            defaults.set(false, forKey: Keys.guestLocalEnabled)
        }

        updateAuthStateFromSources()
    }

    private func updateAuthStateFromSources() {
        if let user = remoteUser {
            authState = .signedIn(uid: user.uid, email: user.email)
            return
        }

        if isGuestLocalEnabled {
            authState = .guestLocal
            return
        }

        authState = .signedOut
    }

    private func validateEmail(_ input: String) throws -> String {
        let normalized = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.contains("@"), normalized.contains(".") else {
            throw AuthError.invalidEmail
        }
        return normalized
    }

    private func validatePassword(_ input: String) throws -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 6 else {
            throw AuthError.invalidPassword
        }
        return trimmed
    }

    private func mapAuthError(_ error: Error) -> AuthError {
        if error is FirebaseAuthAdapterError {
            return .backendUnavailable
        }

#if canImport(FirebaseAuth)
        let nsError = error as NSError
        guard let code = AuthErrorCode(rawValue: nsError.code) else {
            return .unknown
        }

        switch code {
        case .invalidEmail:
            return .invalidEmail
        case .emailAlreadyInUse:
            return .emailAlreadyInUse
        case .userNotFound:
            return .accountNotFound
        case .wrongPassword, .invalidCredential:
            return .wrongPassword
        default:
            return .unknown
        }
#else
        return .unknown
#endif
    }
}

private struct DisabledFirebaseAuthAdapter: FirebaseAuthAdapting {
    func currentUser() -> AuthSessionUser? {
        nil
    }

    func listenAuthState(_ handler: @escaping @Sendable (AuthSessionUser?) -> Void) -> AuthStateListenerHandle {
        handler(nil)
        return AuthStateListenerHandle {}
    }

    func signIn(email _: String, password _: String) async throws {
        throw FirebaseAuthAdapterError.unavailable
    }

    func signUp(email _: String, password _: String) async throws {
        throw FirebaseAuthAdapterError.unavailable
    }

    func signOut() throws {}
}
