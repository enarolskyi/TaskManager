import SwiftUI

struct TaskCardView: View {
    @Environment(TaskStore.self) private var store
    let task: TaskItem

    private var isDone: Bool { task.status == .done }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                Task { await store.toggleComplete(task) }
            } label: {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isDone ? Color.appDark : .secondary)
            }
            .buttonStyle(.borderless)   // в List інакше тап по рядку натискає всі кнопки
            .accessibilityIdentifier("task.checkbox")

            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .font(.subheadline.weight(.medium))
                    .strikethrough(isDone)

                if !task.details.isEmpty {
                    Text(task.details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .strikethrough(isDone)
                }

                HStack(spacing: 12) {
                    Text(task.priority.title)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(task.priority.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(task.priority.color.opacity(0.2), in: Capsule())
                        .fixedSize()

                    // Тег стискається першим і обрізається "…", дата завжди повністю.
                    // Без Label: з fixedSize він інколи ховає текст і лишає тільки іконку
                    HStack(spacing: 4) {
                        Image(systemName: "tag")
                        Text(task.tag)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        Text(dueDateText)
                            .lineLimit(1)
                    }
                    .foregroundStyle(isOverdue ? Color.red : Color.secondary)
                    .fixedSize()
                    .layoutPriority(1)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Menu {
                ForEach(TaskStatus.allCases.filter { $0 != task.status }) { status in
                    Button("Move to \(status.title)") {
                        Task { await store.move(task, to: status) }
                    }
                }
                Divider()
                Button("Delete task", role: .destructive) {
                    Task { store.report(await store.delete(task)) }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(Color.appDark)
                    .padding(6)
            }
            .accessibilityIdentifier("task.menu")
        }
        .padding(14)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }

    private var isOverdue: Bool {
        !isDone && task.dueDate < Calendar.current.startOfDay(for: .now)
    }

    private var dueDateText: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(task.dueDate) { return "Today" }
        if calendar.isDateInTomorrow(task.dueDate) { return "Tomorrow" }
        return task.dueDate.formatted(.dateTime.day().month(.abbreviated))
    }
}

#Preview {
    TaskCardView(task: TaskItem(id: 1, title: "Create weekly workout plan",
                                details: "Sign up for trainings, make sure all in calendar with notifications",
                                status: .todo, priority: .medium, tag: "Sport", dueDate: .now))
        .padding()
        .background(Color.appBackground)
        .environment(TaskStore())
}
