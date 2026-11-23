import Foundation
import Observation

@Observable
final class AuthViewModel {

    var currentUser: User? {
        didSet { cacheUser(currentUser) }
    }
    var isRestoringSession = true

    var isLoggedIn: Bool { currentUser != nil }

    private let api = APIClient.shared
    private let userCacheKey = "cachedUser"

    /// Відновлення сесії за збереженим токеном.
    /// Якщо юзер є в кеші — одразу показуємо застосунок і перевіряємо токен у фоні,
    /// щоб не блокувати старт на холодному старті сервера.
    func restoreSession() async {
        guard api.token != nil else {
            isRestoringSession = false
            return
        }

        if let cached = cachedUser() {
            currentUser = cached
            isRestoringSession = false
            await verifyToken()   // фонова перевірка: оновить юзера або розлогінить при 401
        } else {
            await verifyToken()
            isRestoringSession = false
        }
    }

    /// Перевіряє токен запитом /me. 401 → вихід; мережа недоступна → лишаємо як є
    private func verifyToken() async {
        do {
            currentUser = try await api.get("/me")
        } catch APIError.unauthorized {
            forceLogout()
        } catch {
            // недоступний сервер або скасування — нічого не робимо
        }
    }

    // Кеш юзера — щоб показати застосунок одразу при наступному запуску
    private func cachedUser() -> User? {
        guard let data = UserDefaults.standard.data(forKey: userCacheKey) else { return nil }
        return try? JSONDecoder().decode(User.self, from: data)
    }

    private func cacheUser(_ user: User?) {
        if let user, let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userCacheKey)
        } else {
            UserDefaults.standard.removeObject(forKey: userCacheKey)
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
        } catch APIError.cancelled {
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
