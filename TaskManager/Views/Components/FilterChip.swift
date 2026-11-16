import SwiftUI

// Активний фільтр під пошуком, × прибирає його
struct FilterChip: View {
    let title: String
    let onRemove: () -> Void

    var body: some View {
        Button(action: onRemove) {
            HStack(spacing: 4) {
                Text(title)
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(Color.appOnDark)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.appDark, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("chip.\(title)")
    }
}

#Preview {
    HStack {
        FilterChip(title: "High") {}
        FilterChip(title: "#Sport") {}
    }
}
