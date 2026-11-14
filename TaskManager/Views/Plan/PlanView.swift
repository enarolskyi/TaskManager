import SwiftUI

struct PlanView: View {
    @Environment(TaskStore.self) private var store
    @Environment(AuthViewModel.self) private var auth

    @State private var selectedStatus: TaskStatus = .todo
    @State private var isShowingNewTask = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                header
                statusTabs
                taskList
            }

            AddTaskButton { isShowingNewTask = true }
                .padding(20)
        }
        .background(Color.appBackground)
        .task {
            await store.load()
        }
        .sheet(isPresented: $isShowingNewTask) {
            NewTaskView()
                .environment(store)
        }
        // Алерт помилок — у MainTabView
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

    // MARK: - Status tabs

    private var statusTabs: some View {
        HStack {
            ForEach(TaskStatus.allCases) { status in
                let isSelected = status == selectedStatus
                let count = store.tasks(with: status).count

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
        .padding(.vertical, 20)
    }

    // MARK: - Task list

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

    private var taskList: some View {
        let tasks = store.tasks(with: selectedStatus)

        return ScrollView {
            if store.isLoading && store.tasks.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
            } else if tasks.isEmpty {
                EmptyStateView(icon: emptyIcon, title: emptyTitle, subtitle: emptySubtitle)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(tasks) { task in
                        TaskCardView(task: task)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 90)   // місце під кнопку Add task
            }
        }
        .refreshable {
            await store.load()
        }
        .animation(.default, value: store.tasks)
    }
}

#Preview {
    PlanView()
        .environment(AuthViewModel())
        .environment(TaskStore())
}
