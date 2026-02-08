import SwiftUI

struct SignUpView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?

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

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button("Create Account") {
                    handleSignUp()
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle("Sign Up")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }

    private func handleSignUp() {
        do {
            try sessionManager.signUp(email: email, password: password)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
