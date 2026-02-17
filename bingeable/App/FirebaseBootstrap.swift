import Foundation

#if canImport(FirebaseCore)
import FirebaseCore
#endif

enum FirebaseBootstrap {
    private static var didAttemptConfigure = false
    private(set) static var isConfigured = false

    static func configureIfAvailable() {
        guard !didAttemptConfigure else {
            return
        }
        didAttemptConfigure = true

#if canImport(FirebaseCore)
        for candidate in configurationCandidates() {
            guard let path = Bundle.main.path(forResource: candidate, ofType: "plist") else {
                continue
            }

            if candidate == "GoogleService-Info" {
                FirebaseApp.configure()
                isConfigured = true
                return
            }

            if let options = FirebaseOptions(contentsOfFile: path) {
                FirebaseApp.configure(options: options)
                isConfigured = true
                return
            }

            NSLog("Firebase skipped: unable to parse %@.plist in app bundle.", candidate)
        }

        NSLog("Firebase skipped: no GoogleService-Info plist found in app bundle.")
#endif
    }

    private static func configurationCandidates() -> [String] {
        let env = ProcessInfo.processInfo.environment
        if let explicit = env["FIREBASE_CONFIG_NAME"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !explicit.isEmpty {
            return [explicit, "GoogleService-Info", "GoogleService-Info-Dev", "GoogleService-Info-Prod"]
        }

#if DEBUG
        return ["GoogleService-Info", "GoogleService-Info-Dev", "GoogleService-Info-Prod"]
#else
        return ["GoogleService-Info", "GoogleService-Info-Prod", "GoogleService-Info-Dev"]
#endif
    }
}
