import SwiftUI

struct ForgotPasswordView: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(AuthRouter.self) private var router

    @State private var email: String
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(initialEmail: String = "") {
        _email = State(initialValue: initialEmail)
    }

    private var isEmailValid: Bool { Validator.isValidEmail(email) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Reset password")
                    .font(.system(size: 32))
                    .padding(.top, 20)

                Text("Enter the email you used to sign up. We'll send you a 6-digit code.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)

                AppTextField(label: "Email address", text: $email,
                             keyboard: .emailAddress, accessibilityId: "forgot.email")
                FieldError(value: email, isValid: isEmailValid, message: "Invalid email format")

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("forgot.error")
                }

                PrimaryButton(title: "Send code", isEnabled: isEmailValid, isLoading: isLoading) {
                    Task { await sendCode() }
                }
                .accessibilityIdentifier("forgot.submit")
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
        }
        .background(Color.appBackground)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: email) { errorMessage = nil }
    }

    private func sendCode() async {
        let normalized = email.trimmingCharacters(in: .whitespaces).lowercased()
        isLoading = true
        errorMessage = await auth.requestPasswordReset(email: normalized)
        isLoading = false
        if errorMessage == nil {
            router.showResetPassword(email: normalized)
        }
    }
}

#Preview {
    NavigationStack {
        ForgotPasswordView(initialEmail: "ed@test.com")
    }
    .environment(AuthViewModel())
    .environment(AuthRouter())
}
