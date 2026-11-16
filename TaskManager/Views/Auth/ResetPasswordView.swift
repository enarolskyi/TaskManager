import SwiftUI

struct ResetPasswordView: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(AuthRouter.self) private var router

    let email: String

    @State private var code = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var isResending = false
    @State private var errorMessage: String?
    @State private var info: String?
    // Той самий cooldown, що й на бекенді
    @State private var resendAvailableAt = Date.now.addingTimeInterval(60)

    private static let codeLength = 6

    private var isCodeValid: Bool { code.count == Self.codeLength }
    private var isPasswordValid: Bool { Validator.isValidPassword(newPassword) }
    private var passwordsMatch: Bool { !confirmPassword.isEmpty && newPassword == confirmPassword }
    private var canSubmit: Bool { isCodeValid && isPasswordValid && passwordsMatch }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Enter code")
                    .font(.system(size: 32))
                    .padding(.top, 20)

                Text("We sent a 6-digit code to \(email). It's valid for 15 minutes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                #if DEBUG
                // Поки немає справжньої пошти, код друкується в консолі бекенду
                Label("Dev: the code is printed in the backend (uvicorn) console", systemImage: "terminal")
                    .font(.caption)
                    .foregroundStyle(.orange)
                #endif

                AppTextField(label: "6-digit code", text: $code,
                             keyboard: .numberPad, accessibilityId: "reset.code")
                    .padding(.top, 8)
                    .onChange(of: code) { _, value in
                        // Тільки цифри і не більше 6
                        let digits = String(value.filter(\.isNumber).prefix(Self.codeLength))
                        if digits != value { code = digits }
                    }

                AppTextField(label: "New password", text: $newPassword,
                             isSecure: true, accessibilityId: "reset.newPassword")

                AppTextField(label: "Confirm new password", text: $confirmPassword,
                             isSecure: true, accessibilityId: "reset.confirmPassword")
                FieldError(value: confirmPassword, isValid: passwordsMatch, message: "Passwords don't match")

                Text("8+ characters, 1 uppercase, 1 number")
                    .font(.caption)
                    .foregroundStyle(newPassword.isEmpty || isPasswordValid ? Color.secondary : Color.red)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("reset.error")
                }
                if let info {
                    Text(info)
                        .font(.footnote)
                        .foregroundStyle(.green)
                }

                PrimaryButton(title: "Reset password", isEnabled: canSubmit, isLoading: isLoading) {
                    Task { await submit() }
                }
                .accessibilityIdentifier("reset.submit")
                .padding(.top, 8)

                resendButton
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 24)
        }
        .background(Color.appBackground)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: [code, newPassword, confirmPassword]) {
            errorMessage = nil
        }
    }

    // TimelineView щосекунди перемальовує кнопку — так зворотний відлік працює без таймерів
    private var resendButton: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let secondsLeft = max(0, Int(resendAvailableAt.timeIntervalSince(context.date).rounded(.up)))

            Button {
                Task { await resend() }
            } label: {
                Text(secondsLeft > 0 ? "Resend code in \(secondsLeft)s" : "Resend code")
                    .monospacedDigit()
            }
            .font(.footnote)
            .foregroundStyle(secondsLeft > 0 ? Color.secondary : Color.appDark)
            .disabled(secondsLeft > 0 || isResending)
            .accessibilityIdentifier("reset.resend")
        }
    }

    private func submit() async {
        isLoading = true
        info = nil
        errorMessage = await auth.resetPassword(email: email, code: code, newPassword: newPassword)
        isLoading = false
        if errorMessage == nil {
            router.finishPasswordReset()
        }
    }

    private func resend() async {
        isResending = true
        info = nil
        errorMessage = await auth.requestPasswordReset(email: email)
        isResending = false
        if errorMessage == nil {
            code = ""
            info = "A new code has been sent"
            resendAvailableAt = .now.addingTimeInterval(60)
        }
    }
}

#Preview {
    NavigationStack {
        ResetPasswordView(email: "ed@test.com")
    }
    .environment(AuthViewModel())
    .environment(AuthRouter())
}
