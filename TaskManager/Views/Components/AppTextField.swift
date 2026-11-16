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
    @FocusState private var isFocused: Bool

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
                .focused($isFocused)
                .font(.subheadline)
                .keyboardType(keyboard)
                .textInputAutocapitalization(capitalization)
                .autocorrectionDisabled()
                .accessibilityIdentifier(accessibilityId)
            }

            if isSecure {
                Button {
                    toggleReveal()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("\(accessibilityId).toggle")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 52)
        // Тап будь-де в рамці фокусує поле, а не тільки по рядку тексту
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isFocused ? Color.appDark : Color.appBorder, lineWidth: isFocused ? 1.5 : 1)
        )
        .animation(.easeInOut(duration: 0.15), value: text.isEmpty)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }

    // SecureField і TextField — різні view, тож при перемиканні фокус губиться. Повертаємо його.
    private func toggleReveal() {
        let wasFocused = isFocused
        isRevealed.toggle()
        if wasFocused {
            DispatchQueue.main.async { isFocused = true }
        }
    }
}

#Preview {
    VStack {
        AppTextField(label: "Email address", text: .constant("test@test.com"))
        AppTextField(label: "Password", text: .constant(""), isSecure: true)
    }
    .padding()
}
