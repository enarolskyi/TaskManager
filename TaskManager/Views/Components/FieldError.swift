import SwiftUI

// Показується лише для непорожнього невалідного значення
struct FieldError: View {
    let value: String
    let isValid: Bool
    let message: String

    var body: some View {
        if !value.isEmpty && !isValid {
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
