import SwiftUI

// Одна форма для створення і редагування задачі
struct TaskFormView: View {
    enum Mode {
        case create(initialDate: Date)
        case edit(TaskItem)
    }

    @Environment(TaskStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var title: String
    @State private var details: String
    @State private var tag: String
    @State private var dueDate: Date
    @State private var priority: TaskPriority
    @State private var status: TaskStatus

    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var isShowingDeleteConfirm = false

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .create(let initialDate):
            _title = State(initialValue: "")
            _details = State(initialValue: "")
            _tag = State(initialValue: "")
            _dueDate = State(initialValue: initialDate)
            _priority = State(initialValue: .low)
            _status = State(initialValue: .todo)
        case .edit(let task):
            _title = State(initialValue: task.title)
            _details = State(initialValue: task.details)
            _tag = State(initialValue: task.tag)
            _dueDate = State(initialValue: task.dueDate)
            _priority = State(initialValue: task.priority)
            _status = State(initialValue: task.status)
        }
    }

    private var editingTask: TaskItem? {
        if case .edit(let task) = mode { return task }
        return nil
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedDetails: String {
        details.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedTag: String {
        let value = tag.trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? "General" : value
    }

    /// Тільки поля, що змінилися — їх і шлемо в PATCH
    private var changes: TaskUpdateRequest {
        guard let task = editingTask else { return TaskUpdateRequest() }
        var request = TaskUpdateRequest()
        if trimmedTitle != task.title { request.title = trimmedTitle }
        if trimmedDetails != task.details { request.details = trimmedDetails }
        if normalizedTag != task.tag { request.tag = normalizedTag }
        if !Calendar.current.isDate(dueDate, inSameDayAs: task.dueDate) { request.dueDate = dueDate }
        if priority != task.priority { request.priority = priority }
        if status != task.status { request.status = status }
        return request
    }

    private var canSave: Bool {
        guard !trimmedTitle.isEmpty, !isSaving else { return false }
        return editingTask == nil || !changes.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Enter title", text: $title)
                        .accessibilityIdentifier("taskForm.title")
                    TextField("Enter description", text: $details, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityIdentifier("taskForm.description")
                }

                Section {
                    DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
                        .accessibilityIdentifier("taskForm.dueDate")
                    HStack {
                        TextField("Enter a tag", text: $tag)
                            .textInputAutocapitalization(.words)
                            .accessibilityIdentifier("taskForm.tag")
                        Text("\(tag.count)/\(TaskItem.maxTagLength)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }
                    // Обрізаємо і при вставці з буфера
                    .onChange(of: tag) { _, newValue in
                        if newValue.count > TaskItem.maxTagLength {
                            tag = String(newValue.prefix(TaskItem.maxTagLength))
                        }
                    }
                }

                Section("Priority") {
                    Picker("Priority", selection: $priority) {
                        ForEach(TaskPriority.allCases) { priority in
                            Text(priority.title).tag(priority)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("taskForm.priority")
                }

                // Статус міняємо тільки для існуючої задачі, нова завжди To-do
                if editingTask != nil {
                    Section("Status") {
                        Picker("Status", selection: $status) {
                            ForEach(TaskStatus.allCases) { status in
                                Text(status.title).tag(status)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("taskForm.status")
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("taskForm.error")
                    }
                }

                if editingTask != nil {
                    Section {
                        Button("Delete task", role: .destructive) {
                            isShowingDeleteConfirm = true
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("taskForm.delete")
                    }
                }
            }
            .navigationTitle(editingTask == nil ? "New task" : "Task details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("taskForm.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button(editingTask == nil ? "Done" : "Save") {
                            Task { await save() }
                        }
                        .disabled(!canSave)
                        .accessibilityIdentifier("taskForm.save")
                    }
                }
            }
            .confirmationDialog("Delete this task?", isPresented: $isShowingDeleteConfirm,
                                titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    Task { await deleteTask() }
                }
            } message: {
                Text("This can't be undone.")
            }
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil

        if let task = editingTask {
            errorMessage = await store.update(task, with: changes)
        } else {
            errorMessage = await store.add(NewTaskRequest(
                title: trimmedTitle,
                details: trimmedDetails,
                priority: priority,
                tag: normalizedTag,
                dueDate: dueDate
            ))
        }

        isSaving = false
        if errorMessage == nil { dismiss() }
    }

    private func deleteTask() async {
        guard let task = editingTask else { return }
        isSaving = true
        errorMessage = await store.delete(task)
        isSaving = false
        if errorMessage == nil { dismiss() }
    }
}

#Preview("Create") {
    TaskFormView(mode: .create(initialDate: .now))
        .environment(TaskStore())
}

#Preview("Edit") {
    TaskFormView(mode: .edit(TaskItem(id: 1, title: "Water the flowers", details: "",
                                      status: .todo, priority: .low, tag: "Home", dueDate: .now)))
        .environment(TaskStore())
}
