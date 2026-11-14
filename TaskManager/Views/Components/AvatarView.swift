import SwiftUI

struct AvatarView: View {
    let name: String
    var size: CGFloat = 44

    private var initials: String {
        name.split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }

    var body: some View {
        Circle()
            .fill(Color.gray.opacity(0.25))
            .frame(width: size, height: size)
            .overlay {
                Text(initials.isEmpty ? "?" : initials)
                    .font(.system(size: size * 0.38, weight: .medium))
                    .foregroundStyle(Color.appDark)
            }
    }
}

#Preview {
    HStack {
        AvatarView(name: "Ed Test")
        AvatarView(name: "Eduard", size: 88)
    }
}
