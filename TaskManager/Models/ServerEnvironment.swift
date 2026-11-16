import Foundation

// Куди застосунок шле запити: хмара чи локальний бекенд на маку.
// Вибір зберігається на пристрої (UserDefaults) — APIClient читає його на кожен запит.
enum ServerEnvironment: String, CaseIterable, Identifiable {
    case cloud
    case local

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cloud: "Cloud"
        case .local: "Local Mac"
        }
    }

    private enum Keys {
        static let environment = "server.environment"
        static let cloudURL = "server.cloudURL"
    }

    // URL хмарного бекенду (Render). Поки не задеплоєно — порожній, редагується в More → Server.
    static let defaultCloudURL = "https://taskmanager-api-npie.onrender.com"

    static var current: ServerEnvironment {
        get {
            let raw = UserDefaults.standard.string(forKey: Keys.environment)
            return raw.flatMap(ServerEnvironment.init) ?? .local
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Keys.environment) }
    }

    static var cloudURL: String {
        get { UserDefaults.standard.string(forKey: Keys.cloudURL) ?? defaultCloudURL }
        set { UserDefaults.standard.set(newValue, forKey: Keys.cloudURL) }
    }
}
