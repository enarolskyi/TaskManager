import Foundation

// rawValue — значення в API, title — для UI

enum TaskStatus: String, CaseIterable, Identifiable, Codable {
    case todo = "todo"
    case inProgress = "in_progress"
    case done = "done"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .todo: "To-do"
        case .inProgress: "In progress"
        case .done: "Complete"
        }
    }
}

enum TaskPriority: String, CaseIterable, Identifiable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low: "Low"
        case .medium: "Middle"
        case .high: "High"
        }
    }
}

// Поля відповідають TaskOut на бекенді
struct TaskItem: Identifiable, Codable, Equatable {
    let id: Int
    var title: String
    var details: String
    var status: TaskStatus
    var priority: TaskPriority
    var tag: String
    var dueDate: Date

    /// Той самий ліміт, що й на бекенді
    static let maxTagLength = 20
}
