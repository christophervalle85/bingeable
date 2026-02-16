import SwiftUI

struct SignUpView: View {
    @EnvironmentObject private var sessionManager: SessionManager

    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        Form {
            Section("Create account") {
                TextField("Email", text: $email)
#if os(iOS)
                    .textInputAutocapitalization(.never)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
#endif

                SecureField("Password", text: $password)
#if os(iOS)
                    .textContentType(.newPassword)
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
                Button(isLoading ? "Creating..." : "Create Account") {
                    Task {
                        await handleSignUp()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .disabled(isLoading)
            }
        }
        .navigationTitle("Sign Up")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }

    private func handleSignUp() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            try await sessionManager.signUp(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
