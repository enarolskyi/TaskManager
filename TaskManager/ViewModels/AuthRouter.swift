import Foundation
import Observation

enum AuthRoute: Hashable {
    case login
    case register
}

// Навігація для незалогіненого юзера: Welcome → Login / Register
@Observable
final class AuthRouter {
    var path: [AuthRoute] = []

    func showLogin() {
        // Register відкрили з Login — просто повертаємось назад
        if path.dropLast().last == .login {
            path.removeLast()
        } else {
            path = [.login]
        }
    }

    func showRegister() {
        if path.dropLast().last == .register {
            path.removeLast()
        } else {
            path.append(.register)
        }
    }

    func reset() {
        path = []
    }
}
