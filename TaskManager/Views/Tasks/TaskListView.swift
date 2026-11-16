import SwiftUI

// Список карток для Plan і Calendar: тап → редагування, свайпи → швидкі дії.
// swipeActions працюють тільки в List, тому тут List, стилізований під картки.
struct TaskListView: View {
    @Environment(TaskStore.self) private var store

    let tasks: [TaskItem]

    @State private var editingTask: TaskItem?
    @State private var pendingAction: PendingAction?

    private enum PendingAction: Identifiable {
        case delete(TaskItem)
        case move(TaskItem)

        var id: String {
            switch self {
            case .delete(let task): "delete-\(task.id)"
            case .move(let task): "move-\(task.id)"
            }
        }

        var task: TaskItem {
            switch self {
            case .delete(let task), .move(let task): task
            }
        }
    }

    var body: some View {
        List {
            ForEach(tasks) { task in
                TaskCardView(task: task)
                    .contentShape(Rectangle())
                    .onTapGesture { editingTask = task }
                    .listRowInsets(EdgeInsets(top: 6, leading: 24, bottom: 6, trailing: 24))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        completeButton(for: task)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        // Без role: .destructive — інакше List одразу прибирає рядок, ще до підтвердження
                        Button {
                            pendingAction = .delete(task)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)

                        Button {
                            pendingAction = .move(task)
                        } label: {
                            Label("Move", systemImage: "arrow.right.arrow.left")
                        }
                        .tint(.gray)
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, 90, for: .scrollContent)   // місце під кнопку Add task
        .animation(.default, value: tasks)
        .sheet(item: $editingTask) { task in
            TaskFormView(mode: .edit(task))
                .environment(store)
        }
        .confirmationDialog(dialogTitle, isPresented: isShowingDialog,
                            titleVisibility: .visible, presenting: pendingAction) { action in
            switch action {
            case .delete(let task):
                Button("Delete", role: .destructive) {
                    Task {
                        store.report(await store.delete(task))
                        Haptics.success()
                    }
                }
            case .move(let task):
                ForEach(TaskStatus.allCases.filter { $0 != task.status }) { status in
                    Button(status.title) {
                        Task {
                            await store.move(task, to: status)
                            Haptics.success()
                        }
                    }
                }
            }
        } message: { action in
            if case .delete = action {
                Text("This can't be undone.")
            }
        }
    }

    private func completeButton(for task: TaskItem) -> some View {
        let isDone = task.status == .done
        return Button {
            Task {
                await store.toggleComplete(task)
                Haptics.success()
            }
        } label: {
            Label(isDone ? "Undo" : "Complete",
                  systemImage: isDone ? "arrow.uturn.backward" : "checkmark")
        }
        .tint(isDone ? Color.orange : Color.green)
    }

    private var dialogTitle: String {
        switch pendingAction {
        case .delete(let task): "Delete \"\(task.title)\"?"
        case .move: "Move to"
        case nil: ""
        }
    }

    private var isShowingDialog: Binding<Bool> {
        Binding(
            get: { pendingAction != nil },
            set: { if !$0 { pendingAction = nil } }
        )
    }
}

enum Haptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

#Preview {
    TaskListView(tasks: [
        TaskItem(id: 1, title: "Create weekly workout plan", details: "Sign up for trainings",
                 status: .todo, priority: .medium, tag: "Sport", dueDate: .now),
        TaskItem(id: 2, title: "Water the flowers", details: "",
                 status: .done, priority: .low, tag: "Home", dueDate: .now),
    ])
    .environment(TaskStore())
    .background(Color.appBackground)
}
