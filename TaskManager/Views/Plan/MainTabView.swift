import SwiftUI

struct MainTabView: View {
    @Environment(TaskStore.self) private var store

    var body: some View {
        TabView {
            PlanView()
                .tabItem { Label("Plan", systemImage: "house.fill") }

            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }

            MoreView()
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
        }
        .tint(Color.appDark)
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
}
