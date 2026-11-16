import Foundation
import WidgetKit

// Те, що застосунок передає віджету через спільний App Group.
// Така сама структура є у віджеті (TaskManagerWidget/WidgetSnapshot.swift) — поля мають збігатися.
struct WidgetSnapshot: Codable {
    struct Item: Codable, Hashable {
        let id: Int
        let title: String
        let priority: String    // low / medium / high
        let dueDate: Date
    }

    var isLoggedIn: Bool
    var items: [Item]           // тільки невиконані задачі
    var updatedAt: Date
}

enum WidgetSync {
    static let appGroup = "group.com.eduard.TaskManager"
    static let key = "widget.snapshot"

    // Віджет сам рахує "сьогодні" і "прострочені" в момент показу,
    // тому передаємо задачі з запасом на тиждень — щоб він не застарів, якщо застосунок довго не відкривали
    private static let daysAhead = 7
    private static let maxItems = 40

    static func update(with tasks: [TaskItem]) {
        let calendar = Calendar.current
        let limit = calendar.date(byAdding: .day, value: daysAhead, to: calendar.startOfDay(for: .now)) ?? .now

        let items = tasks
            .filter { $0.status != .done && $0.dueDate <= limit }
            .sorted { $0.dueDate == $1.dueDate ? $0.id < $1.id : $0.dueDate < $1.dueDate }
            .prefix(maxItems)
            .map { WidgetSnapshot.Item(id: $0.id, title: $0.title, priority: $0.priority.rawValue, dueDate: $0.dueDate) }

        save(WidgetSnapshot(isLoggedIn: true, items: Array(items), updatedAt: .now))
    }

    /// Після Log out віджет не повинен показувати задачі попереднього юзера
    static func clear() {
        save(WidgetSnapshot(isLoggedIn: false, items: [], updatedAt: .now))
    }

    private static func save(_ snapshot: WidgetSnapshot) {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
