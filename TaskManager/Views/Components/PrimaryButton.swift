import SwiftUI

struct PrimaryButton: View {
    let title: String
    var isEnabled = true
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView().tint(Color.appOnDark)
                } else {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.appOnDark)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isEnabled ? Color.appDark : Color.gray)
            )
        }
        .disabled(!isEnabled || isLoading)
    }
}

#Preview {
    VStack {
        PrimaryButton(title: "Sign up") {}
        PrimaryButton(title: "Sign up", isEnabled: false) {}
        PrimaryButton(title: "Sign up", isLoading: true) {}
    }
    .padding()
}
