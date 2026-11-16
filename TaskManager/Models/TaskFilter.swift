import Foundation

enum DueFilter: String, CaseIterable, Identifiable {
    case any, today, thisWeek, overdue

    var id: String { rawValue }

    var title: String {
        switch self {
        case .any: "Any"
        case .today: "Today"
        case .thisWeek: "This week"
        case .overdue: "Overdue"
        }
    }
}

enum TaskSortOption: String, CaseIterable, Identifiable {
    case created, dueDate, priority, name

    var id: String { rawValue }

    var title: String {
        switch self {
        case .created: "Created"
        case .dueDate: "Due date"
        case .priority: "Priority"
        case .name: "Name"
        }
    }
}

// Фільтрація на клієнті: задачі вже завантажені, тож результат миттєвий
struct TaskFilter: Equatable {
    var searchText = ""
    var priorities: Set<TaskPriority> = []
    var tags: Set<String> = []
    var due: DueFilter = .any
    var sort: TaskSortOption = .created

    /// Для бейджа на кнопці фільтрів (пошук і сортування не рахуємо)
    var activeCount: Int {
        priorities.count + tags.count + (due == .any ? 0 : 1)
    }

    var isActive: Bool {
        activeCount > 0 || !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    mutating func resetFilters() {
        priorities = []
        tags = []
        due = .any
        sort = .created
    }

    func apply(to tasks: [TaskItem], calendar: Calendar = .current) -> [TaskItem] {
        tasks
            .filter { matches($0, calendar: calendar) }
            .sorted(by: sortComparator)
    }

    private func matches(_ task: TaskItem, calendar: Calendar) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty,
           !task.title.localizedCaseInsensitiveContains(query),
           !task.details.localizedCaseInsensitiveContains(query),
           !task.tag.localizedCaseInsensitiveContains(query) {
            return false
        }
        if !priorities.isEmpty && !priorities.contains(task.priority) { return false }
        if !tags.isEmpty && !tags.contains(task.tag) { return false }

        switch due {
        case .any:
            return true
        case .today:
            return calendar.isDateInToday(task.dueDate)
        case .thisWeek:
            return calendar.isDate(task.dueDate, equalTo: .now, toGranularity: .weekOfYear)
        case .overdue:
            // Виконані задачі не вважаємо простроченими
            return task.status != .done && task.dueDate < calendar.startOfDay(for: .now)
        }
    }

    private func sortComparator(_ a: TaskItem, _ b: TaskItem) -> Bool {
        switch sort {
        case .created:
            return a.id < b.id
        case .dueDate:
            return (a.dueDate, a.id) < (b.dueDate, b.id)
        case .priority:
            return (a.priority.rank, a.id) < (b.priority.rank, b.id)
        case .name:
            let order = a.title.localizedCaseInsensitiveCompare(b.title)
            return order == .orderedSame ? a.id < b.id : order == .orderedAscending
        }
    }
}

private extension TaskPriority {
    /// High першим при сортуванні
    var rank: Int {
        switch self {
        case .high: 0
        case .medium: 1
        case .low: 2
        }
    }
}
