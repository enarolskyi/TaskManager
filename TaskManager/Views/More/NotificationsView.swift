import SwiftUI
import UserNotifications

struct NotificationsView: View {
    @Environment(NotificationManager.self) private var notifications
    @Environment(TaskStore.self) private var store
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @State private var testSent = false

    private var isDenied: Bool { notifications.authorizationStatus == .denied }

    var body: some View {
        Form {
            if isDenied {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Notifications are turned off", systemImage: "bell.slash")
                            .font(.headline)
                        Text("Allow notifications for Task Manager in iOS Settings to get reminders.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                                openURL(url)
                            }
                        }
                        .accessibilityIdentifier("notifications.openSettings")
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                Toggle("Task reminders", isOn: taskRemindersBinding)
                    .accessibilityIdentifier("notifications.taskReminders")
                DatePicker("Remind at", selection: timeBinding(\.reminderMinutes), displayedComponents: .hourAndMinute)
                    .disabled(!notifications.taskRemindersEnabled)
                    .accessibilityIdentifier("notifications.reminderTime")
            } footer: {
                Text("On the due date of every unfinished task.")
            }

            Section {
                Toggle("Morning overview", isOn: overviewBinding)
                    .accessibilityIdentifier("notifications.overview")
                DatePicker("Send at", selection: timeBinding(\.overviewMinutes), displayedComponents: .hourAndMinute)
                    .disabled(!notifications.overviewEnabled)
                    .accessibilityIdentifier("notifications.overviewTime")
            } footer: {
                Text("How many tasks are due today and how many are overdue. Skipped on days with nothing planned.")
            }

            Section {
                Button(testSent ? "Sent — wait 5 seconds" : "Send test notification") {
                    Task {
                        await notifications.sendTestNotification()
                        testSent = true
                        try? await Task.sleep(for: .seconds(5))
                        testSent = false
                    }
                }
                .disabled(testSent || isDenied)
                .accessibilityIdentifier("notifications.test")
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Color.appDark)
        .task { await notifications.refreshStatus() }
        // Юзер міг увімкнути дозвіл в iOS Settings і повернутись
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await notifications.refreshStatus()
                    notifications.reschedule(for: store.tasks)
                }
            }
        }
    }

    private var taskRemindersBinding: Binding<Bool> {
        Binding(get: { notifications.taskRemindersEnabled },
                set: { newValue in Task { await notifications.setTaskReminders(newValue) } })
    }

    private var overviewBinding: Binding<Bool> {
        Binding(get: { notifications.overviewEnabled },
                set: { newValue in Task { await notifications.setOverview(newValue) } })
    }

    // DatePicker працює з Date, а зберігаємо хвилини від півночі
    private func timeBinding(_ keyPath: ReferenceWritableKeyPath<NotificationManager, Int>) -> Binding<Date> {
        Binding(
            get: {
                let minutes = notifications[keyPath: keyPath]
                return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60,
                                             second: 0, of: .now) ?? .now
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                notifications[keyPath: keyPath] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
    }
    .environment(NotificationManager())
    .environment(TaskStore())
}
