import Foundation
import Observation

enum AuthRoute: Hashable {
    case login
    case register
    case forgotPassword(email: String)
    case resetPassword(email: String)
}

// Навігація для незалогіненого юзера: Welcome → Login / Register
@Observable
final class AuthRouter {
    var path: [AuthRoute] = []
    /// Повідомлення над формою логіну (напр. після скидання пароля)
    var loginNotice: String?

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

    func showForgotPassword(email: String) {
        path.append(.forgotPassword(email: email))
    }

    func showResetPassword(email: String) {
        path.append(.resetPassword(email: email))
    }

    /// Пароль змінено → назад на Login з повідомленням
    func finishPasswordReset() {
        loginNotice = "Password updated. Log in with your new password"
        path = [.login]
    }

    func reset() {
        path = []
        loginNotice = nil
    }
}
