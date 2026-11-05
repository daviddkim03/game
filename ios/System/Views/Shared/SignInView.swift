import SwiftUI
import SystemCore

struct SignInView: View {
    @Environment(AppModel.self) private var model
    @State private var email = ""
    @State private var password = ""
    @State private var error: String?
    @State private var isSigningIn = false

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 12) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(Color(hex: "#171717"), in: RoundedRectangle(cornerRadius: 15))
                Text("System")
                    .font(.title2.bold())
            }

            VStack(spacing: 12) {
                TextField("Email", text: $email)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("signin.email")
                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .accessibilityIdentifier("signin.password")
                    .onSubmit(submit)
            }
            .textFieldStyle(.roundedBorder)

            if let error {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("signin.error")
            }

            Button(action: submit) {
                Group {
                    if isSigningIn {
                        ProgressView()
                    } else {
                        Text("Sign in")
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 28)
            }
            .buttonStyle(.borderedProminent)
            .disabled(email.isEmpty || password.isEmpty || isSigningIn)
            .accessibilityIdentifier("signin.submit")
        }
        .padding(28)
        .frame(maxWidth: 400)
    }

    private func submit() {
        guard !email.isEmpty, !password.isEmpty, !isSigningIn else { return }
        isSigningIn = true
        error = nil
        Task {
            do {
                try await model.signIn(email: email, password: password)
            } catch {
                self.error = Self.message(for: error)
                isSigningIn = false
            }
        }
    }

    private static func message(for error: Error) -> String {
        switch error as? CloudError {
        case .invalidCredentials: "Wrong email or password."
        case .tooManyAttempts: "Too many attempts. Wait a moment and try again."
        case .offline: "No connection. Try again when you're online."
        case .server(let detail): detail
        default: "Couldn't sign in."
        }
    }
}
