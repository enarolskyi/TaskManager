import SwiftUI

// Кольори з підтримкою light/dark
extension Color {
    static let appDark = Color(lightMode: UIColor(red: 0.07, green: 0.09, blue: 0.15, alpha: 1),
                               darkMode: UIColor(red: 0.93, green: 0.94, blue: 0.96, alpha: 1))
    static let appOnDark = Color(lightMode: .white,
                                 darkMode: UIColor(red: 0.07, green: 0.09, blue: 0.15, alpha: 1))
    static let appBackground = Color(lightMode: UIColor(red: 0.97, green: 0.97, blue: 0.98, alpha: 1),
                                     darkMode: .black)
    static let appCard = Color(lightMode: .white,
                               darkMode: UIColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1))
    static let appBorder = Color.gray.opacity(0.35)

    init(lightMode light: UIColor, darkMode dark: UIColor) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

extension TaskPriority {
    var color: Color {
        switch self {
        case .low: .green
        case .medium: .orange
        case .high: .red
        }
    }
}

extension AppTheme {
    /// nil — системна тема
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
