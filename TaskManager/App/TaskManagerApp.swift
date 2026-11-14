import SwiftUI

@main
struct TaskManagerApp: App {
    @State private var auth = AuthViewModel()
    @State private var store = TaskStore()
    @State private var settingsStore = SettingsStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(store)
                .environment(settingsStore)
        }
    }
}

struct RootView: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(TaskStore.self) private var store
    @Environment(SettingsStore.self) private var settingsStore

    @State private var router = AuthRouter()

    var body: some View {
        Group {
            if auth.isRestoringSession {
                ProgressView()
            } else if auth.isLoggedIn {
                MainTabView()
            } else {
                NavigationStack(path: $router.path) {
                    WelcomeView { wantsRegister in
                        if wantsRegister {
                            router.showRegister()
                        } else {
                            router.showLogin()
                        }
                    }
                    .navigationDestination(for: AuthRoute.self) { route in
                        switch route {
                        case .login: LoginView()
                        case .register: RegisterView()
                        }
                    }
                }
                .environment(router)
            }
        }
        .animation(.default, value: auth.isLoggedIn)
        .preferredColorScheme(settingsStore.settings.theme.colorScheme)
        .task {
            store.onUnauthorized = { [auth] in auth.forceLogout() }
            await auth.restoreSession()
        }
        // Після логіну вантажимо налаштування, після логауту чистимо стан
        .onChange(of: auth.isLoggedIn) { _, isLoggedIn in
            if isLoggedIn {
                router.reset()
                Task { await settingsStore.load() }
            } else {
                store.reset()
                settingsStore.reset()
                router.reset()
            }
        }
    }
}
