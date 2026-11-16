import SwiftUI

struct PlanView: View {
    @Environment(TaskStore.self) private var store
    @Environment(AuthViewModel.self) private var auth

    @State private var selectedStatus: TaskStatus = .todo
    @State private var isShowingNewTask = false
    @State private var isShowingFilter = false
    // Живе, поки відкритий застосунок (TabView тримає PlanView в пам'яті)
    @State private var filter = TaskFilter()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                header
                searchBar
                if filter.activeCount > 0 {
                    activeFilters
                }
                statusTabs
                content
            }

            AddTaskButton { isShowingNewTask = true }
                .padding(20)
        }
        .background(Color.appBackground)
        .task {
            await store.load()
        }
        .sheet(isPresented: $isShowingNewTask) {
            TaskFormView(mode: .create(initialDate: .now))
                .environment(store)
        }
        .sheet(isPresented: $isShowingFilter) {
            TaskFilterView(filter: $filter, availableTags: store.allTags)
        }
        // Алерт помилок — у MainTabView
    }

    private func visibleTasks(for status: TaskStatus) -> [TaskItem] {
        filter.apply(to: store.tasks(with: status))
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date.now.formatted(.dateTime.weekday(.abbreviated).month(.wide).day()))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Today")
                    .font(.system(size: 30))
            }

            Spacer()

            Menu {
                if let user = auth.currentUser {
                    Text("Hi, \(user.fullName)")
                }
                Button("Log out", role: .destructive) {
                    Task { await auth.logout() }
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.title3)
                    .foregroundStyle(Color.appDark)
                    .padding(8)
            }
            .accessibilityIdentifier("plan.menu")
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    // MARK: - Search & filters

    private var searchBar: some View {
        HStack(spacing: 10) {
            SearchField(text: $filter.searchText)

            Button {
                isShowingFilter = true
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.appDark)
                    .frame(width: 40, height: 40)
                    .background(Color.appCard, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appBorder))
                    .overlay(alignment: .topTrailing) {
                        if filter.activeCount > 0 {
                            Text("\(filter.activeCount)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(minWidth: 18, minHeight: 18)
                                .background(Color.red, in: Circle())
                                .offset(x: 6, y: -6)
                        }
                    }
            }
            .accessibilityIdentifier("plan.filter")
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    private var activeFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TaskPriority.allCases.filter { filter.priorities.contains($0) }) { priority in
                    FilterChip(title: priority.title) { filter.priorities.remove(priority) }
                }
                ForEach(filter.tags.sorted(), id: \.self) { tag in
                    FilterChip(title: "#\(tag)") { filter.tags.remove(tag) }
                }
                if filter.due != .any {
                    FilterChip(title: filter.due.title) { filter.due = .any }
                }

                Button("Reset") {
                    withAnimation { filter.resetFilters() }
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.appDark)
                .accessibilityIdentifier("plan.resetFilters")
            }
            .padding(.horizontal, 24)
        }
        .padding(.top, 10)
    }

    // MARK: - Status tabs

    private var statusTabs: some View {
        HStack {
            ForEach(TaskStatus.allCases) { status in
                let isSelected = status == selectedStatus
                // Лічильник враховує пошук і фільтри
                let count = visibleTasks(for: status).count

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedStatus = status
                    }
                } label: {
                    Text("\(status.title) (\(count))")
                        .font(.subheadline.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Color.appDark : .secondary)
                        .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("plan.tab.\(status.rawValue)")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        let tasks = visibleTasks(for: selectedStatus)

        if store.isLoading && store.tasks.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 100)
            Spacer()
        } else if tasks.isEmpty {
            ScrollView {
                if filter.isActive && !store.tasks(with: selectedStatus).isEmpty {
                    EmptyStateView(icon: "magnifyingglass",
                                   title: "No tasks match your filters",
                                   actionTitle: "Clear filters") {
                        withAnimation {
                            filter.resetFilters()
                            filter.searchText = ""
                        }
                    }
                } else {
                    EmptyStateView(icon: emptyIcon, title: emptyTitle, subtitle: emptySubtitle)
                }
            }
            .refreshable { await store.load() }
        } else {
            TaskListView(tasks: tasks)
                .refreshable { await store.load() }
        }
    }

    private var emptyIcon: String {
        switch selectedStatus {
        case .todo: "tray"
        case .inProgress: "hourglass"
        case .done: "checkmark.circle"
        }
    }

    private var emptyTitle: String {
        switch selectedStatus {
        case .todo: "No tasks to do"
        case .inProgress: "Nothing in progress"
        case .done: "No completed tasks yet"
        }
    }

    private var emptySubtitle: String? {
        selectedStatus == .todo ? "Tap \"Add task\" to create one" : nil
    }
}

#Preview {
    PlanView()
        .environment(AuthViewModel())
        .environment(TaskStore())
}
