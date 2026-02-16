import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var sessionManager: SessionManager

    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        Form {
            Section("Credentials") {
                TextField("Email", text: $email)
#if os(iOS)
                    .textInputAutocapitalization(.never)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
#endif

                SecureField("Password", text: $password)
#if os(iOS)
                    .textContentType(.password)
#endif
            }

            Section {
                Button("Continue as Guest") {
                    errorMessage = nil
                    sessionManager.enterGuestLocal()
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button(isLoading ? "Signing In..." : "Sign In") {
                    Task {
                        await handleSignIn()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .disabled(isLoading)
            }
        }
        .navigationTitle("Sign In")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }

    private func handleSignIn() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            try await sessionManager.signIn(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
