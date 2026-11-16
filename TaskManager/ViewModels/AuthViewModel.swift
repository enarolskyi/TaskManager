import Foundation
import Observation

@Observable
final class AuthViewModel {

    var currentUser: User?
    var isRestoringSession = true

    var isLoggedIn: Bool { currentUser != nil }

    private let api = APIClient.shared

    /// Відновлення сесії за збереженим токеном
    func restoreSession() async {
        defer { isRestoringSession = false }
        guard api.token != nil else { return }

        do {
            let user: User = try await api.get("/me")
            currentUser = user
        } catch APIError.unauthorized {
            api.token = nil
        } catch {
            // сервер недоступний — токен не скидаємо
        }
    }

    /// Повертає текст помилки або nil
    func login(email: String, password: String) async -> String? {
        do {
            let response: AuthResponse = try await api.post(
                "/auth/login",
                body: LoginRequest(email: email, password: password)
            )
            api.token = response.token
            currentUser = response.user
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func register(fullName: String, phone: String, email: String, password: String) async -> String? {
        do {
            let response: AuthResponse = try await api.post(
                "/auth/register",
                body: RegisterRequest(fullName: fullName, phone: phone, email: email, password: password)
            )
            api.token = response.token
            currentUser = response.user
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    // MARK: - Скидання пароля (без логіну)

    /// Сервер відповідає однаково для будь-якого email, тож помилка тут — лише мережева/валідація
    func requestPasswordReset(email: String) async -> String? {
        do {
            try await api.postNoContent("/auth/forgot-password", body: ForgotPasswordRequest(email: email))
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func resetPassword(email: String, code: String, newPassword: String) async -> String? {
        do {
            try await api.postNoContent("/auth/reset-password",
                                        body: ResetPasswordRequest(email: email, code: code, newPassword: newPassword))
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func logout() async {
        try? await api.postNoContent("/auth/logout")   // виходимо локально, навіть якщо сервер недоступний
        forceLogout()
    }

    /// Вихід без запиту до сервера (напр. при 401)
    func forceLogout() {
        api.token = nil
        currentUser = nil
    }

    // MARK: - Профіль

    func updateProfile(fullName: String, phone: String, email: String) async -> String? {
        await perform {
            let user: User = try await api.patch(
                "/me",
                body: UpdateProfileRequest(fullName: fullName, phone: phone, email: email)
            )
            currentUser = user
        }
    }

    func changePassword(current: String, new: String) async -> String? {
        await perform {
            try await api.postNoContent(
                "/me/password",
                body: ChangePasswordRequest(currentPassword: current, newPassword: new)
            )
        }
    }

    func deleteAccount() async -> String? {
        await perform {
            try await api.delete("/me")
            forceLogout()
        }
    }

    /// 401 → logout, інше → текст помилки
    private func perform(_ operation: () async throws -> Void) async -> String? {
        do {
            try await operation()
            return nil
        } catch APIError.unauthorized {
            forceLogout()
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
