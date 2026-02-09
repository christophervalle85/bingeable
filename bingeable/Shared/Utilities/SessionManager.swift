import Foundation
import Combine

@MainActor
final class SessionManager: ObservableObject {
    enum AuthState: Equatable {
        case undetermined
        case guest
        case signedIn(email: String)
    }

    enum AuthError: LocalizedError {
        case invalidEmail
        case invalidPassword
        case accountAlreadyExists
        case accountNotFound
        case wrongPassword

        var errorDescription: String? {
            switch self {
            case .invalidEmail:
                return "Enter a valid email address."
            case .invalidPassword:
                return "Password must have at least 6 characters."
            case .accountAlreadyExists:
                return "An account already exists for that email."
            case .accountNotFound:
                return "No account found for that email."
            case .wrongPassword:
                return "The password is incorrect."
            }
        }
    }

    @Published private(set) var authState: AuthState = .undetermined

    var profileScopeIdentifier: String {
        switch authState {
        case let .signedIn(email):
            return email
        case .guest:
            return "guest"
        case .undetermined:
            return "signed_out"
        }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let guestMode = "session.guestMode"
        static let currentEmail = "session.currentEmail"
        static let accounts = "session.accounts"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        restoreState()
    }

    func continueAsGuest() {
        defaults.set(true, forKey: Keys.guestMode)
        defaults.removeObject(forKey: Keys.currentEmail)
        authState = .guest
    }

    func signIn(email: String, password: String) throws {
        let normalizedEmail = try validateEmail(email)
        let password = try validatePassword(password)

        guard let storedPassword = accounts[normalizedEmail] else {
            throw AuthError.accountNotFound
        }

        guard storedPassword == password else {
            throw AuthError.wrongPassword
        }

        defaults.set(normalizedEmail, forKey: Keys.currentEmail)
        defaults.set(false, forKey: Keys.guestMode)
        authState = .signedIn(email: normalizedEmail)
    }

    func signUp(email: String, password: String) throws {
        let normalizedEmail = try validateEmail(email)
        let password = try validatePassword(password)

        var nextAccounts = accounts
        guard nextAccounts[normalizedEmail] == nil else {
            throw AuthError.accountAlreadyExists
        }

        nextAccounts[normalizedEmail] = password
        saveAccounts(nextAccounts)
        defaults.set(normalizedEmail, forKey: Keys.currentEmail)
        defaults.set(false, forKey: Keys.guestMode)
        authState = .signedIn(email: normalizedEmail)
    }

    func signOut() {
        defaults.removeObject(forKey: Keys.currentEmail)
        defaults.removeObject(forKey: Keys.guestMode)
        authState = .undetermined
    }

    private func restoreState() {
        if let currentEmail = defaults.string(forKey: Keys.currentEmail), !currentEmail.isEmpty {
            authState = .signedIn(email: currentEmail)
            return
        }

        if defaults.bool(forKey: Keys.guestMode) {
            authState = .guest
            return
        }

        authState = .undetermined
    }

    private var accounts: [String: String] {
        guard let data = defaults.data(forKey: Keys.accounts) else {
            return [:]
        }

        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }

    private func saveAccounts(_ accounts: [String: String]) {
        if let encoded = try? JSONEncoder().encode(accounts) {
            defaults.set(encoded, forKey: Keys.accounts)
        }
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
}
