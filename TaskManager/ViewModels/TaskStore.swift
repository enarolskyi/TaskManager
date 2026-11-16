import Foundation
import Observation

@Observable
final class TaskStore {

    var tasks: [TaskItem] = []
    var isLoading = false
    var errorMessage: String?

    /// Задається в RootView — розлогінює при 401
    var onUnauthorized: (() -> Void)?

    private let api = APIClient.shared

    func tasks(with status: TaskStatus) -> [TaskItem] {
        tasks.filter { $0.status == status }
    }

    /// Унікальні теги з усіх задач — для фільтра
    var allTags: [String] {
        Set(tasks.map(\.tag)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        report(await perform {
            tasks = try await api.get("/tasks")
        })
    }

    // add / update / delete повертають текст помилки або nil.
    // Форма показує помилку в себе, а дії зі списку йдуть у спільний алерт через report().

    func add(_ request: NewTaskRequest) async -> String? {
        await perform {
            let task: TaskItem = try await api.post("/tasks", body: request)
            tasks.append(task)
        }
    }

    func update(_ task: TaskItem, with request: TaskUpdateRequest) async -> String? {
        guard !request.isEmpty else { return nil }
        return await perform {
            let updated: TaskItem = try await api.patch("/tasks/\(task.id)", body: request)
            replace(updated)
        }
    }

    func delete(_ task: TaskItem) async -> String? {
        await perform {
            try await api.delete("/tasks/\(task.id)")
            tasks.removeAll { $0.id == task.id }
        }
    }

    func move(_ task: TaskItem, to status: TaskStatus) async {
        report(await update(task, with: TaskUpdateRequest(status: status)))
    }

    func toggleComplete(_ task: TaskItem) async {
        await move(task, to: task.status == .done ? .todo : .done)
    }

    /// Показати помилку в алерті MainTabView
    func report(_ error: String?) {
        if let error { errorMessage = error }
    }

    func reset() {
        tasks = []
        errorMessage = nil
    }

    // MARK: - Helpers

    private func replace(_ task: TaskItem) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
        }
    }

    /// 401 → logout (без тексту помилки), інше → текст помилки
    private func perform(_ operation: () async throws -> Void) async -> String? {
        do {
            try await operation()
            return nil
        } catch APIError.unauthorized {
            onUnauthorized?()
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
