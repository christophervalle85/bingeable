import Foundation

struct AuthSessionUser: Equatable, Sendable {
    let uid: String
    let email: String?
}

final class AuthStateListenerHandle {
    private let cancelClosure: () -> Void
    private var isCancelled = false

    init(cancelClosure: @escaping () -> Void) {
        self.cancelClosure = cancelClosure
    }

    func cancel() {
        guard !isCancelled else {
            return
        }

        isCancelled = true
        cancelClosure()
    }

    deinit {
        cancel()
    }
}

protocol FirebaseAuthAdapting {
    func currentUser() -> AuthSessionUser?
    func listenAuthState(_ handler: @escaping @Sendable (AuthSessionUser?) -> Void) -> AuthStateListenerHandle
    func signIn(email: String, password: String) async throws
    func signUp(email: String, password: String) async throws
    func signOut() throws
}

enum FirebaseAuthAdapterError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Firebase Auth is unavailable. Add FirebaseAuth via Swift Package Manager and configure GoogleService-Info.plist."
        }
    }
}

#if canImport(FirebaseAuth)
import FirebaseAuth

struct FirebaseAuthAdapter: FirebaseAuthAdapting {
    init() {
#if DEBUG
        if AppConfiguration.firebaseAuthUseEmulator {
            Auth.auth().useEmulator(
                withHost: AppConfiguration.firebaseAuthEmulatorHost,
                port: AppConfiguration.firebaseAuthEmulatorPort
            )
        }
#endif
    }

    func currentUser() -> AuthSessionUser? {
        map(user: Auth.auth().currentUser)
    }

    func listenAuthState(_ handler: @escaping @Sendable (AuthSessionUser?) -> Void) -> AuthStateListenerHandle {
        let listener = Auth.auth().addStateDidChangeListener { _, user in
            handler(map(user: user))
        }

        return AuthStateListenerHandle {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    func signIn(email: String, password: String) async throws {
        _ = try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func signUp(email: String, password: String) async throws {
        _ = try await Auth.auth().createUser(withEmail: email, password: password)
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    private func map(user: User?) -> AuthSessionUser? {
        guard let user else {
            return nil
        }

        return AuthSessionUser(uid: user.uid, email: user.email)
    }
}
#else
struct FirebaseAuthAdapter: FirebaseAuthAdapting {
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
#endif
