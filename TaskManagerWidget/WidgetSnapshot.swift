import Foundation

// Копія структури з застосунку (TaskManager/Services/WidgetSync.swift).
// Віджет — окремий target і не бачить код застосунку, тому поля мають збігатися.
struct WidgetSnapshot: Codable {
    struct Item: Codable, Hashable {
        let id: Int
        let title: String
        let priority: String
        let dueDate: Date
    }

    var isLoggedIn: Bool
    var items: [Item]
    var updatedAt: Date

    static let appGroup = "group.com.eduard.TaskManager"
    static let key = "widget.snapshot"

    static func load() -> WidgetSnapshot? {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    static let sample = WidgetSnapshot(
        isLoggedIn: true,
        items: [
            Item(id: 1, title: "Create weekly workout plan", priority: "medium", dueDate: .now),
            Item(id: 2, title: "Water the flowers", priority: "low", dueDate: .now),
            Item(id: 3, title: "Book a table", priority: "high", dueDate: .now.addingTimeInterval(-86_400)),
        ],
        updatedAt: .now
    )
}
