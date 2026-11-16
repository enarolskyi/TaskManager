import SwiftUI

struct MainTabView: View {
    @Environment(TaskStore.self) private var store
    @Environment(NotificationManager.self) private var notifications

    var body: some View {
        TabView {
            PlanView()
                .tabItem { Label("Plan", systemImage: "house.fill") }

            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }

            NavigationStack {
                ProductivityView()
            }
            .tabItem { Label("Productivity", systemImage: "chart.bar.fill") }

            MoreView()
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
        }
        .tint(Color.appDark)
        // Будь-яка зміна задач → перебудовуємо нагадування
        .onChange(of: store.tasks, initial: true) { _, tasks in
            notifications.reschedule(for: tasks)
        }
        // Спільний алерт помилок для всіх вкладок
        .alert("Error", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )
    }
}

#Preview {
    MainTabView()
        .environment(AuthViewModel())
        .environment(TaskStore())
        .environment(SettingsStore())
        .environment(NotificationManager())
}
