import SwiftUI

struct LaunchGateView: View {
    @EnvironmentObject private var sessionManager: SessionManager

    var body: some View {
        switch sessionManager.authState {
        case .guest, .signedIn:
            MainTabView()
        case .undetermined:
            AuthEntryView()
        }
    }
}

private struct AuthEntryView: View {
    @EnvironmentObject private var sessionManager: SessionManager

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "tv.and.mediabox")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue)

                Text("Bingeable")
                    .font(.largeTitle.weight(.bold))

                Text("Discover shows that are ready to binge, and track what you are waiting on.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)

                Button("Continue as Guest") {
                    sessionManager.continueAsGuest()
                }
                .buttonStyle(.borderedProminent)

                NavigationLink("Sign In") {
                    SignInView()
                }

                NavigationLink("Create Account") {
                    SignUpView()
                }
            }
            .padding()
            .navigationTitle("Welcome")
        }
    }
}
