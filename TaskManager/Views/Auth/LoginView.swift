import SwiftUI

struct LoginView: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(AuthRouter.self) private var router

    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    private var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Log in")
                    .font(.system(size: 32))
                    .padding(.top, 60)
                    .padding(.bottom, 16)

                AppTextField(label: "Email address", text: $email,
                             keyboard: .emailAddress, accessibilityId: "login.email")

                AppTextField(label: "Password", text: $password,
                             isSecure: true, accessibilityId: "login.password")

                Button("Forgot password?") {
                    router.showForgotPassword(email: email.trimmingCharacters(in: .whitespaces))
                }
                .font(.footnote)
                .foregroundStyle(Color.appDark)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityIdentifier("login.forgotPassword")

                if let notice = router.loginNotice {
                    Label(notice, systemImage: "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(.green)
                        .accessibilityIdentifier("login.notice")
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("login.error")
                }

                PrimaryButton(title: "Log in", isEnabled: canSubmit, isLoading: isLoading) {
                    Task {
                        isLoading = true
                        router.loginNotice = nil
                        errorMessage = await auth.login(email: email, password: password)
                        isLoading = false
                    }
                }
                .accessibilityIdentifier("login.submit")
                .padding(.top, 8)

                HStack(spacing: 4) {
                    Text("Don't have an account?")
                    Button {
                        router.showRegister()
                    } label: {
                        Text("Sign up").underline()
                    }
                    .accessibilityIdentifier("login.goToSignUp")
                }
                .font(.footnote)
                .foregroundStyle(Color.appDark)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
        }
        .background(Color.appBackground)
        .onChange(of: email) { errorMessage = nil }
        .onChange(of: password) { errorMessage = nil }
    }
}

#Preview {
    NavigationStack {
        LoginView()
    }
    .environment(AuthViewModel())
    .environment(AuthRouter())
}
