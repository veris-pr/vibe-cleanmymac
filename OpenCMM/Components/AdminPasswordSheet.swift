import SwiftUI

/// Native password prompt sheet for admin actions.
struct AdminPasswordSheet: View {
    @ObservedObject var authManager: AdminAuthManager
    @State private var password = ""
    @State private var showPassword = false
    @FocusState private var isPasswordFocused: Bool

    var body: some View {
        VStack(spacing: 20) {
            // Icon + Title
            VStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(Theme.Colors.secondary)

                Text("OpenCMM needs your password")
                    .font(Theme.Font.heading)
                    .foregroundStyle(Theme.Colors.foreground)

                Text(authManager.promptMessage)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Colors.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }

            // Password field
            HStack {
                Group {
                    if showPassword {
                        TextField("Password", text: $password)
                    } else {
                        SecureField("Password", text: $password)
                    }
                }
                .textFieldStyle(.plain)
                .font(Theme.Font.body)
                .focused($isPasswordFocused)
                .onSubmit { submit() }

                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Colors.muted)
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .background(Theme.Colors.muted.opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Theme.Colors.border, lineWidth: 1)
            )
            .frame(width: 280)

            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    password = ""
                    authManager.cancelPrompt()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Button("Authenticate") { submit() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(password.isEmpty)
            }
        }
        .padding(30)
        .frame(width: 380)
        .onAppear { isPasswordFocused = true }
    }

    private func submit() {
        guard !password.isEmpty else { return }
        let pw = password
        password = ""
        authManager.submitPassword(pw)
    }
}
