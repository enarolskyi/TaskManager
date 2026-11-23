import Foundation
import Observation

@Observable
final class SettingsStore {

    var settings = UserSettings.defaults
    var errorMessage: String?

    private let api = APIClient.shared

    func load() async {
        do {
            settings = try await api.get("/settings")
        } catch APIError.cancelled {
            // запит скасовано — не помилка
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Optimistic update: одразу оновлюємо UI, потім зберігаємо на сервер
    func setTheme(_ theme: AppTheme) {
        settings.theme = theme
        save(SettingsUpdateRequest(theme: theme))
    }

    func setTimezone(_ timezone: String) {
        settings.timezone = timezone
        save(SettingsUpdateRequest(timezone: timezone))
    }

    func setWeekStart(_ weekStart: WeekStart) {
        settings.weekStart = weekStart
        save(SettingsUpdateRequest(weekStart: weekStart))
    }

    func setDailyGoal(_ goal: Int) {
        settings.dailyGoal = goal
        save(SettingsUpdateRequest(dailyGoal: goal))
    }

    func setWeeklyGoal(_ goal: Int) {
        settings.weeklyGoal = goal
        save(SettingsUpdateRequest(weeklyGoal: goal))
    }

    func reset() {
        settings = .defaults
        errorMessage = nil
    }

    // При помилці перечитуємо налаштування, щоб відкотити зміну
    private func save(_ request: SettingsUpdateRequest) {
        errorMessage = nil
        Task {
            do {
                settings = try await api.patch("/settings", body: request)
            } catch APIError.cancelled {
                // скасовано — лишаємо optimistic-значення
            } catch {
                errorMessage = error.localizedDescription
                await load()
            }
        }
    }
}
