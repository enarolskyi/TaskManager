import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

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

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.appDark)
                    .padding(.top, 6)
                    .accessibilityIdentifier("emptyState.action")
            }
        }
        .frame(maxWidth: .infinity)   // щоб вміст був по центру
        .padding(.horizontal, 40)
        .padding(.top, 100)
    }
}

#Preview {
    EmptyStateView(icon: "magnifyingglass", title: "No tasks match your filters",
                   actionTitle: "Clear filters") {}
}
