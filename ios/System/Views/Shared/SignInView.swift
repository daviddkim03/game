import SwiftUI
import SystemCore

struct SignInView: View {
    @Environment(AppModel.self) private var model
    @State private var password = ""
    @State private var error: String?
    @State private var isSigningIn = false
    @FocusState private var isTyping: Bool

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

            SecureField("Password", text: $password)
                .textContentType(.password)
                .textFieldStyle(.roundedBorder)
                .focused($isTyping)
                .accessibilityIdentifier("signin.password")
                .onSubmit(submit)

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
            .disabled(password.isEmpty || isSigningIn)
            .accessibilityIdentifier("signin.submit")
        }
        .padding(28)
        .frame(maxWidth: 400)
        .onAppear { isTyping = true }
    }

    private func submit() {
        guard !password.isEmpty, !isSigningIn else { return }
        isSigningIn = true
        error = nil
        Task {
            do {
                try await model.signIn(password: password)
            } catch {
                self.error = Self.message(for: error)
                isSigningIn = false
            }
        }
    }

    private static func message(for error: Error) -> String {
        switch error as? CloudError {
        case .invalidCredentials: "Wrong password."
        case .tooManyAttempts: "Too many attempts. Wait a moment and try again."
        case .offline: "No connection. Try again when you're online."
        case .server(let detail): detail
        default: "Couldn't sign in."
        }
    }
}
