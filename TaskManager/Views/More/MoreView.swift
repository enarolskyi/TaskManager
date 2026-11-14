import SwiftUI

struct MoreView: View {
    @Environment(AuthViewModel.self) private var auth

    var body: some View {
        NavigationStack {
            List {
                if let user = auth.currentUser {
                    Section {
                        HStack(spacing: 12) {
                            AvatarView(name: user.fullName)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.fullName)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    NavigationLink { AccountView() } label: {
                        Label("Account", systemImage: "person")
                    }
                    .accessibilityIdentifier("more.account")

                    NavigationLink { GeneralView() } label: {
                        Label("General", systemImage: "gearshape")
                    }
                    .accessibilityIdentifier("more.general")

                    NavigationLink { NotificationsView() } label: {
                        Label("Notifications", systemImage: "bell")
                    }
                    .accessibilityIdentifier("more.notifications")

                    NavigationLink { HelpFeedbackView() } label: {
                        Label("Help & Feedback", systemImage: "questionmark.circle")
                    }
                    .accessibilityIdentifier("more.help")
                }

                Section {
                    Button("Log out", role: .destructive) {
                        Task { await auth.logout() }
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("more.logout")
                }
            }
            .navigationTitle("More")
            .tint(Color.appDark)
        }
    }
}

#Preview {
    MoreView()
        .environment(AuthViewModel())
        .environment(SettingsStore())
}
