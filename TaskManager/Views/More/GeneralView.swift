import SwiftUI

// Кожна зміна одразу зберігається (PATCH /settings)
struct GeneralView: View {
    @Environment(SettingsStore.self) private var settingsStore

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Colour theme", selection: themeBinding) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.title).tag(theme)
                    }
                }
                .accessibilityIdentifier("general.theme")
            }

            Section("Date & Time") {
                Picker("Timezone", selection: timezoneBinding) {
                    ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { identifier in
                        Text(identifier.replacingOccurrences(of: "_", with: " ")).tag(identifier)
                    }
                }
                .pickerStyle(.navigationLink)
                .accessibilityIdentifier("general.timezone")

                Picker("Start week on", selection: weekStartBinding) {
                    ForEach(WeekStart.allCases) { day in
                        Text(day.title).tag(day)
                    }
                }
                .accessibilityIdentifier("general.weekStart")
            }

            if let error = settingsStore.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("general.error")
                }
            }
        }
        .navigationTitle("General")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Color.appDark)
        .task {
            await settingsStore.load()
        }
    }

    private var themeBinding: Binding<AppTheme> {
        Binding(get: { settingsStore.settings.theme },
                set: { settingsStore.setTheme($0) })
    }

    private var timezoneBinding: Binding<String> {
        Binding(get: { settingsStore.settings.timezone },
                set: { settingsStore.setTimezone($0) })
    }

    private var weekStartBinding: Binding<WeekStart> {
        Binding(get: { settingsStore.settings.weekStart },
                set: { settingsStore.setWeekStart($0) })
    }
}

#Preview {
    NavigationStack {
        GeneralView()
    }
    .environment(SettingsStore())
}
