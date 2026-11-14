import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tertiary)

            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)

            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        // щоб вміст був по центру
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
        .padding(.top, 100)
    }
}

#Preview {
    EmptyStateView(icon: "tray", title: "No tasks here yet", subtitle: "Tap \"Add task\" to create one")
}
