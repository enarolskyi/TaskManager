import SwiftUI

struct RegisterView: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(AuthRouter.self) private var router

    @State private var fullName = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    private var isNameValid: Bool { Validator.isValidFullName(fullName) }
    private var isPhoneValid: Bool { Validator.isValidPhone(phone) }
    private var isEmailValid: Bool { Validator.isValidEmail(email) }
    private var isPasswordValid: Bool { Validator.isValidPassword(password) }
    private var passwordsMatch: Bool { !confirmPassword.isEmpty && password == confirmPassword }

    private var isFormValid: Bool {
        isNameValid && isPhoneValid && isEmailValid && isPasswordValid && passwordsMatch
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Sign up")
                    .font(.system(size: 32))
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                AppTextField(label: "Full name", text: $fullName,
                             capitalization: .words, accessibilityId: "register.fullName")
                fieldError(fullName, isValid: isNameValid, message: "Enter your full name")

                AppTextField(label: "Phone", text: $phone,
                             keyboard: .phonePad, accessibilityId: "register.phone")
                fieldError(phone, isValid: isPhoneValid, message: "Phone must contain 10–15 digits")

                AppTextField(label: "Email address", text: $email,
                             keyboard: .emailAddress, accessibilityId: "register.email")
                fieldError(email, isValid: isEmailValid, message: "Invalid email format")

                AppTextField(label: "Password", text: $password,
                             isSecure: true, accessibilityId: "register.password")

                AppTextField(label: "Confirm password", text: $confirmPassword,
                             isSecure: true, accessibilityId: "register.confirmPassword")
                fieldError(confirmPassword, isValid: passwordsMatch, message: "Passwords don't match")

                Text("8+ characters, 1 uppercase, 1 number")
                    .font(.caption)
                    .foregroundStyle(password.isEmpty || isPasswordValid ? Color.secondary : Color.red)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("register.error")
                }

                PrimaryButton(title: "Sign up", isEnabled: isFormValid, isLoading: isLoading) {
                    Task {
                        isLoading = true
                        errorMessage = await auth.register(fullName: fullName, phone: phone,
                                                           email: email, password: password)
                        isLoading = false
                    }
                }
                .accessibilityIdentifier("register.submit")
                .padding(.top, 8)

                HStack(spacing: 4) {
                    Text("Already have an account?")
                    Button {
                        router.showLogin()
                    } label: {
                        Text("Log in").underline()
                    }
                    .accessibilityIdentifier("register.goToLogin")
                }
                .font(.footnote)
                .foregroundStyle(Color.appDark)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
        }
        .background(Color.appBackground)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func fieldError(_ value: String, isValid: Bool, message: String) -> some View {
        if !value.isEmpty && !isValid {
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
        }
    }
}

#Preview {
    NavigationStack {
        RegisterView()
    }
    .environment(AuthViewModel())
    .environment(AuthRouter())
}
