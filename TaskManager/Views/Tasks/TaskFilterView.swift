import SwiftUI

struct TaskFilterView: View {
    @Binding var filter: TaskFilter
    let availableTags: [String]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Sort by") {
                    Picker("Sort by", selection: $filter.sort) {
                        ForEach(TaskSortOption.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("filter.sort")
                }

                Section("Priority") {
                    ForEach(TaskPriority.allCases) { priority in
                        checkRow(priority.title, isOn: filter.priorities.contains(priority)) {
                            filter.priorities.toggle(priority)
                        }
                        .accessibilityIdentifier("filter.priority.\(priority.rawValue)")
                    }
                }

                if !availableTags.isEmpty {
                    Section("Tag") {
                        ForEach(availableTags, id: \.self) { tag in
                            checkRow(tag, isOn: filter.tags.contains(tag)) {
                                filter.tags.toggle(tag)
                            }
                            .accessibilityIdentifier("filter.tag.\(tag)")
                        }
                    }
                }

                Section("Due date") {
                    Picker("Due date", selection: $filter.due) {
                        ForEach(DueFilter.allCases) { due in
                            Text(due.title).tag(due)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    .accessibilityIdentifier("filter.due")
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Color.appDark)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") { filter.resetFilters() }
                        .disabled(filter.activeCount == 0 && filter.sort == .created)
                        .accessibilityIdentifier("filter.reset")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("filter.done")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func checkRow(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundStyle(Color.primary)
                Spacer()
                if isOn {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.appDark)
                }
            }
        }
    }
}

private extension Set {
    mutating func toggle(_ element: Element) {
        if contains(element) {
            remove(element)
        } else {
            insert(element)
        }
    }
}

#Preview {
    TaskFilterView(filter: .constant(TaskFilter(priorities: [.high], tags: ["Sport"])),
                   availableTags: ["Home", "Sport", "Relationship"])
}
