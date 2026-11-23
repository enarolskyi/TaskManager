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

enum Recurrence: String, CaseIterable, Identifiable, Codable {
    case none, daily, weekly, monthly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "Never"
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        }
    }
}

// Підзадача (чекліст). is_done ↔ isDone конвертує декодер
struct Subtask: Identifiable, Codable, Equatable {
    let id: Int
    var title: String
    var isDone: Bool
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
    var completedAt: Date?           // ставить сервер при переході в Complete
    var recurrence: Recurrence = .none
    var subtasks: [Subtask] = []

    /// Той самий ліміт, що й на бекенді
    static let maxTagLength = 20

    var doneSubtasks: Int { subtasks.filter(\.isDone).count }
    var hasSubtasks: Bool { !subtasks.isEmpty }

    init(id: Int, title: String, details: String, status: TaskStatus,
         priority: TaskPriority, tag: String, dueDate: Date,
         completedAt: Date? = nil, recurrence: Recurrence = .none, subtasks: [Subtask] = []) {
        self.id = id
        self.title = title
        self.details = details
        self.status = status
        self.priority = priority
        self.tag = tag
        self.dueDate = dueDate
        self.completedAt = completedAt
        self.recurrence = recurrence
        self.subtasks = subtasks
    }

    // Власний декодер: recurrence і subtasks можуть бути відсутні (старіший сервер) — беремо дефолт
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        details = try container.decode(String.self, forKey: .details)
        status = try container.decode(TaskStatus.self, forKey: .status)
        priority = try container.decode(TaskPriority.self, forKey: .priority)
        tag = try container.decode(String.self, forKey: .tag)
        dueDate = try container.decode(Date.self, forKey: .dueDate)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        recurrence = try container.decodeIfPresent(Recurrence.self, forKey: .recurrence) ?? .none
        subtasks = try container.decodeIfPresent([Subtask].self, forKey: .subtasks) ?? []
    }
}
