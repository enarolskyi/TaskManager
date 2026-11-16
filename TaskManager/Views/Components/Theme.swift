import SwiftUI

// Кольори в Assets.xcassets (Brand*) з варіантами для light/dark.
// Не через UIColor { traits in ... }: у Swift 6 такий closure ізольований на main actor
// і падає, якщо колір резолвиться з іншого потоку (напр. у Swift Charts).
extension Color {
    static let appDark = Color("BrandInk")
    static let appOnDark = Color("BrandOnInk")
    static let appBackground = Color("BrandBackground")
    static let appCard = Color("BrandCard")
    static let appBorder = Color.gray.opacity(0.35)
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
