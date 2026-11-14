import SwiftUI

// TODO: заглушка, сповіщення ще не реалізовані
struct NotificationsView: View {
    var body: some View {
        Form {
            Section {
                Toggle("Morning overview", isOn: .constant(true))
                Toggle("Task reminders", isOn: .constant(true))
            }

            Section("Tasks") {
                Toggle("Tasks completed", isOn: .constant(true))
                Toggle("Tasks overdue", isOn: .constant(false))
            }

            Section {
                EmptyView()
            } footer: {
                Text("Notifications are coming soon 🚧")
            }
        }
        .disabled(true)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
    }
}
