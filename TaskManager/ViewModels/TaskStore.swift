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

    func load() async {
        isLoading = true
        defer { isLoading = false }
        await run {
            tasks = try await api.get("/tasks")
        }
    }

    // Повертає текст помилки або nil. Помилку показує NewTaskView, тому errorMessage не чіпаємо
    func add(_ request: NewTaskRequest) async -> String? {
        do {
            let task: TaskItem = try await api.post("/tasks", body: request)
            tasks.append(task)
            return nil
        } catch APIError.unauthorized {
            onUnauthorized?()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func move(_ task: TaskItem, to status: TaskStatus) async {
        await run {
            let updated: TaskItem = try await api.patch(
                "/tasks/\(task.id)",
                body: TaskUpdateRequest(status: status)
            )
            replace(updated)
        }
    }

    func toggleComplete(_ task: TaskItem) async {
        await move(task, to: task.status == .done ? .todo : .done)
    }

    func delete(_ task: TaskItem) async {
        await run {
            try await api.delete("/tasks/\(task.id)")
            tasks.removeAll { $0.id == task.id }
        }
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

    private func run(_ operation: () async throws -> Void) async {
        do {
            try await operation()
        } catch APIError.unauthorized {
            onUnauthorized?()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
