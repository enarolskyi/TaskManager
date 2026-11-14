import SwiftUI

// Показується, коли юзер не залогінений
// onFinish(true) — реєстрація, onFinish(false) — логін
struct WelcomeView: View {
    let onFinish: (_ openRegister: Bool) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isAppeared = false

    private let features: [(icon: String, title: String, subtitle: String)] = [
        ("checklist", "Plan your day", "Create tasks with priorities, tags and due dates"),
        ("square.split.3x1", "Track progress", "Move tasks from To-do to Complete"),
        ("calendar", "Stay on schedule", "See what's planned for any day"),
    ]

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                Spacer()

                Image("AppLogo")
                    .resizable()
                    .frame(width: 112, height: 112)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .shadow(color: .indigo.opacity(0.35), radius: 24, y: 12)
                    .scaleEffect(isAppeared ? 1 : 0.6)
                    .opacity(isAppeared ? 1 : 0)

                VStack(spacing: 4) {
                    Text("Welcome to the")
                        .font(.system(size: 26, weight: .regular))
                    Text("Task Manager")
                        .font(.system(size: 36, weight: .bold))
                }
                .foregroundStyle(Color.appDark)
                .multilineTextAlignment(.center)
                .padding(.top, 28)
                .offset(y: isAppeared ? 0 : 20)
                .opacity(isAppeared ? 1 : 0)

                VStack(alignment: .leading, spacing: 22) {
                    ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                        featureRow(icon: feature.icon, title: feature.title, subtitle: feature.subtitle)
                            .offset(y: isAppeared ? 0 : 20)
                            .opacity(isAppeared ? 1 : 0)
                            .animation(.easeOut(duration: 0.5).delay(0.4 + Double(index) * 0.12),
                                       value: isAppeared)
                    }
                }
                .padding(.top, 44)
                .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 12) {
                    PrimaryButton(title: "Let's get started") {
                        onFinish(true)
                    }
                    .accessibilityIdentifier("welcome.getStarted")

                    Button {
                        onFinish(false)
                    } label: {
                        Text("I already have an account")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.appDark)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(RoundedRectangle(cornerRadius: 10).stroke(Color.appDark, lineWidth: 1))
                    }
                    .accessibilityIdentifier("welcome.login")
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .opacity(isAppeared ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.9), value: isAppeared)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) {
                isAppeared = true
            }
        }
    }

    private var background: some View {
        let colors: [Color] = colorScheme == .dark
            ? [Color(red: 0.16, green: 0.10, blue: 0.14), Color(red: 0.10, green: 0.09, blue: 0.20), Color(red: 0.06, green: 0.12, blue: 0.11)]
            : [Color(red: 0.99, green: 0.88, blue: 0.82), Color(red: 0.90, green: 0.89, blue: 0.98), Color(red: 0.86, green: 0.96, blue: 0.88)]
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.appOnDark)
                .frame(width: 44, height: 44)
                .background(Color.appDark, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.appDark)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    WelcomeView { _ in }
}
