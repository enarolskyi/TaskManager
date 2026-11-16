import SwiftUI

struct AccountView: View {
    @Environment(AuthViewModel.self) private var auth

    @State private var fullName = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var didLoad = false

    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var isSaved = false
    @State private var isShowingDeleteConfirm = false

    private var isNameValid: Bool { Validator.isValidFullName(fullName) }
    private var isPhoneValid: Bool { Validator.isValidPhone(phone) }
    private var isEmailValid: Bool { Validator.isValidEmail(email) }

    private var hasChanges: Bool {
        guard let user = auth.currentUser else { return false }
        return fullName != user.fullName
            || phone != user.phone
            || email.trimmingCharacters(in: .whitespaces).lowercased() != user.email
    }

    private var canSave: Bool {
        hasChanges && isNameValid && isPhoneValid && isEmailValid
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                AvatarView(name: fullName, size: 88)
                    .padding(.vertical, 16)

                AppTextField(label: "Full name", text: $fullName,
                             capitalization: .words, accessibilityId: "account.fullName")
                FieldError(value: fullName, isValid: isNameValid, message: "Enter your full name")

                AppTextField(label: "Phone", text: $phone,
                             keyboard: .phonePad, accessibilityId: "account.phone")
                FieldError(value: phone, isValid: isPhoneValid, message: "Phone must contain 10–15 digits")

                AppTextField(label: "Email address", text: $email,
                             keyboard: .emailAddress, accessibilityId: "account.email")
                FieldError(value: email, isValid: isEmailValid, message: "Invalid email format")

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("account.error")
                }
                if isSaved {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(.green)
                        .accessibilityIdentifier("account.saved")
                }

                PrimaryButton(title: "Save changes", isEnabled: canSave, isLoading: isSaving) {
                    Task { await save() }
                }
                .accessibilityIdentifier("account.save")
                .padding(.top, 8)

                NavigationLink {
                    ChangePasswordView()
                } label: {
                    HStack {
                        Text("Change password")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.primary)
                    .padding(.horizontal, 12)
                    .frame(height: 52)
                    .background(RoundedRectangle(cornerRadius: 10).stroke(Color.appBorder))
                }
                .accessibilityIdentifier("account.changePassword")
                .padding(.top, 8)

                Button {
                    isShowingDeleteConfirm = true
                } label: {
                    Text("Delete account").underline()
                }
                .font(.footnote)
                .foregroundStyle(.red)
                .padding(.top, 32)
                .accessibilityIdentifier("account.delete")
            }
            .padding(.horizontal, 24)
        }
        .background(Color.appBackground)
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: fillFromUser)
        .onChange(of: [fullName, phone, email]) {
            errorMessage = nil
            isSaved = false
        }
        .confirmationDialog("Delete account?", isPresented: $isShowingDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Delete account", role: .destructive) {
                Task { errorMessage = await auth.deleteAccount() }
            }
        } message: {
            Text("All your tasks will be deleted. This can't be undone.")
        }
    }

    // didLoad - щоб не затерти введене після повернення з Change password
    private func fillFromUser() {
        guard !didLoad, let user = auth.currentUser else { return }
        fullName = user.fullName
        phone = user.phone
        email = user.email
        didLoad = true
    }

    private func save() async {
        isSaving = true
        errorMessage = await auth.updateProfile(fullName: fullName, phone: phone, email: email)
        isSaving = false
        if errorMessage == nil {
            // Сервер нормалізує дані (напр. email у lowercase)
            didLoad = false
            fillFromUser()
            isSaved = true
        }
    }
}

#Preview {
    NavigationStack {
        AccountView()
    }
    .environment(AuthViewModel())
}
