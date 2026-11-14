import SwiftUI

// Використовується на Plan і Calendar
struct NewTaskView: View {
    @Environment(TaskStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var details = ""
    @State private var tag = ""
    @State private var dueDate: Date
    @State private var priority: TaskPriority = .low
    @State private var isSaving = false
    @State private var errorMessage: String?

    /// Calendar передає обрану дату, Plan — сьогодні
    init(initialDate: Date = .now) {
        _dueDate = State(initialValue: initialDate)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Enter title", text: $title)
                        .accessibilityIdentifier("newTask.title")
                    TextField("Enter description", text: $details, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityIdentifier("newTask.description")
                }

                Section {
                    DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
                    TextField("Enter a tag", text: $tag)
                        .accessibilityIdentifier("newTask.tag")
                }

                Section("Priority") {
                    Picker("Priority", selection: $priority) {
                        ForEach(TaskPriority.allCases) { priority in
                            Text(priority.title).tag(priority)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("newTask.error")
                    }
                }
            }
            .navigationTitle("New task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Done") {
                            Task { await save() }
                        }
                        .disabled(trimmedTitle.isEmpty)
                        .accessibilityIdentifier("newTask.done")
                    }
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil

        let request = NewTaskRequest(
            title: trimmedTitle,
            details: details.trimmingCharacters(in: .whitespacesAndNewlines),
            priority: priority,
            tag: tag.isEmpty ? "General" : tag,
            dueDate: dueDate
        )
        errorMessage = await store.add(request)

        isSaving = false
        if errorMessage == nil { dismiss() }
    }
}

#Preview {
    NewTaskView()
        .environment(TaskStore())
}
