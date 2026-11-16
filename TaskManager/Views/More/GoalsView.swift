import SwiftUI

struct GoalsView: View {
    @Environment(SettingsStore.self) private var settingsStore

    private var settings: UserSettings { settingsStore.settings }

    var body: some View {
        Form {
            Section {
                Stepper(value: dailyGoalBinding, in: UserSettings.goalRange) {
                    goalRow("Daily task goal", value: settings.dailyGoal)
                }
                .accessibilityIdentifier("goals.daily")

                Stepper(value: weeklyGoalBinding, in: UserSettings.goalRange) {
                    goalRow("Weekly task goal", value: settings.weeklyGoal)
                }
                .accessibilityIdentifier("goals.weekly")
            } footer: {
                Text("Used on the Productivity tab. Streak counts days in a row when the daily goal is reached.")
            }

            if let error = settingsStore.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("goals.error")
                }
            }
        }
        .navigationTitle("Goals")
        .navigationBarTitleDisplayMode(.inline)
        .task { await settingsStore.load() }
    }

    private func goalRow(_ title: String, value: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(value)")
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private var dailyGoalBinding: Binding<Int> {
        Binding(get: { settings.dailyGoal }, set: { settingsStore.setDailyGoal($0) })
    }

    private var weeklyGoalBinding: Binding<Int> {
        Binding(get: { settings.weeklyGoal }, set: { settingsStore.setWeeklyGoal($0) })
    }
}

#Preview {
    NavigationStack {
        GoalsView()
    }
    .environment(SettingsStore())
}
