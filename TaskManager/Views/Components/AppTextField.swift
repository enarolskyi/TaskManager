import SwiftUI

// Поле з плаваючим лейблом і перемикачем видимості пароля
struct AppTextField: View {
    let label: String
    @Binding var text: String
    var isSecure = false
    var keyboard: UIKeyboardType = .default
    var capitalization: TextInputAutocapitalization = .never
    var accessibilityId: String = ""

    @State private var isRevealed = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                if !text.isEmpty {
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Group {
                    if isSecure && !isRevealed {
                        SecureField(label, text: $text)
                    } else {
                        TextField(label, text: $text)
                    }
                }
                .font(.subheadline)
                .keyboardType(keyboard)
                .textInputAutocapitalization(capitalization)
                .autocorrectionDisabled()
                .accessibilityIdentifier(accessibilityId)
            }

            if isSecure {
                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("\(accessibilityId).toggle")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.appBorder)
        )
        .animation(.easeInOut(duration: 0.15), value: text.isEmpty)
    }
}

#Preview {
    VStack {
        AppTextField(label: "Email address", text: .constant("test@test.com"))
        AppTextField(label: "Password", text: .constant(""), isSecure: true)
    }
    .padding()
}
