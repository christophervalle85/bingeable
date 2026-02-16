import Foundation

#if canImport(FirebaseCore)
import FirebaseCore
#endif

enum FirebaseBootstrap {
    private static var didConfigure = false

    static func configureIfAvailable() {
        guard !didConfigure else {
            return
        }
        didConfigure = true

#if canImport(FirebaseCore)
        guard FirebaseApp.app() == nil else {
            return
        }

        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            NSLog("Firebase skipped: GoogleService-Info.plist is missing from the app bundle.")
            return
        }

        FirebaseApp.configure()
#endif
    }
}
