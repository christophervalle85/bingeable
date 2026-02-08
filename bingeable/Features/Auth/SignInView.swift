import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?

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

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button("Sign In") {
                    handleSignIn()
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle("Sign In")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }

    private func handleSignIn() {
        do {
            try sessionManager.signIn(email: email, password: password)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
