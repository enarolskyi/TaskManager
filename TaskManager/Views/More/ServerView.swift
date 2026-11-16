import SwiftUI

// More → Server: перемикання між хмарним і локальним бекендом.
// Корисно для розробки: тестувати на локальному маку чи на справжньому сервері.
struct ServerView: View {
    @Environment(AuthViewModel.self) private var auth

    @State private var environment = ServerEnvironment.current
    @State private var cloudURL = ServerEnvironment.cloudURL

    var body: some View {
        Form {
            Section {
                Picker("Server", selection: $environment) {
                    ForEach(ServerEnvironment.allCases) { env in
                        Text(env.title).tag(env)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("server.picker")
            } footer: {
                Text("Switching the server logs you out — accounts live on each server separately.")
            }

            if environment == .cloud {
                Section("Cloud URL") {
                    TextField("https://taskmanager-api.onrender.com", text: $cloudURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .accessibilityIdentifier("server.cloudURL")
                }
            }

            Section {
                Button("Apply") { apply() }
                    .disabled(!hasChanges || (environment == .cloud && !isValidURL))
                    .accessibilityIdentifier("server.apply")
            }
        }
        .navigationTitle("Server")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Color.appDark)
    }

    private var trimmedURL: String {
        cloudURL.trimmingCharacters(in: .whitespaces)
    }

    private var isValidURL: Bool {
        guard let url = URL(string: trimmedURL), let scheme = url.scheme else { return false }
        return (scheme == "http" || scheme == "https") && url.host != nil
    }

    private var hasChanges: Bool {
        environment != ServerEnvironment.current || trimmedURL != ServerEnvironment.cloudURL
    }

    private func apply() {
        ServerEnvironment.cloudURL = trimmedURL
        ServerEnvironment.current = environment
        // Токен належав старому серверу — виходимо, щоб залогінитись на новому
        Task { await auth.logout() }
    }
}

#Preview {
    NavigationStack {
        ServerView()
    }
    .environment(AuthViewModel())
}
