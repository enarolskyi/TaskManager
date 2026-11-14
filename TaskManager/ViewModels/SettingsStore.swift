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
            } catch {
                errorMessage = error.localizedDescription
                await load()
            }
        }
    }
}
