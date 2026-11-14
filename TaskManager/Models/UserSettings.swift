import Foundation

// Налаштування юзера, відповідає SettingsOut на бекенді

enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

enum WeekStart: String, Codable, CaseIterable, Identifiable {
    case monday, sunday

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monday: "Monday"
        case .sunday: "Sunday"
        }
    }
}

struct UserSettings: Codable, Equatable {
    var theme: AppTheme
    var timezone: String
    var weekStart: WeekStart

    // Дефолти збігаються з таблицею user_settings
    static let defaults = UserSettings(theme: .system, timezone: "UTC", weekStart: .monday)
}
