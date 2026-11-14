import SwiftUI

struct ChangePasswordView: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var isNewValid: Bool { Validator.isValidPassword(newPassword) }
    private var passwordsMatch: Bool { !confirmPassword.isEmpty && newPassword == confirmPassword }

    private var canSave: Bool {
        !currentPassword.isEmpty && isNewValid && passwordsMatch
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                AppTextField(label: "Current password", text: $currentPassword,
                             isSecure: true, accessibilityId: "password.current")
                    .padding(.top, 24)

                AppTextField(label: "New password", text: $newPassword,
                             isSecure: true, accessibilityId: "password.new")

                AppTextField(label: "Confirm new password", text: $confirmPassword,
                             isSecure: true, accessibilityId: "password.confirm")
                FieldError(value: confirmPassword, isValid: passwordsMatch, message: "Passwords don't match")

                Text("8+ characters, 1 uppercase, 1 number")
                    .font(.caption)
                    .foregroundStyle(newPassword.isEmpty || isNewValid ? Color.secondary : Color.red)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("password.error")
                }

                PrimaryButton(title: "Change password", isEnabled: canSave, isLoading: isSaving) {
                    Task { await save() }
                }
                .accessibilityIdentifier("password.submit")
                .padding(.top, 8)

                Text("Other devices will be logged out")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
        }
        .background(Color.appBackground)
        .navigationTitle("Change password")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: [currentPassword, newPassword, confirmPassword]) {
            errorMessage = nil
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = await auth.changePassword(current: currentPassword, new: newPassword)
        isSaving = false
        if errorMessage == nil {
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        ChangePasswordView()
    }
    .environment(AuthViewModel())
}
