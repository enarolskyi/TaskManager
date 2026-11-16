import Foundation
import Observation
import UserNotifications

// Локальні нагадування. Налаштування живуть на пристрої (UserDefaults), бо сповіщення — це про конкретний телефон.
@Observable
final class NotificationManager {

    var authorizationStatus: UNAuthorizationStatus = .notDetermined

    var taskRemindersEnabled: Bool {
        didSet { save(taskRemindersEnabled, for: Keys.taskReminders); rescheduleLast() }
    }
    /// Хвилини від півночі: 9:00 → 540
    var reminderMinutes: Int {
        didSet { save(reminderMinutes, for: Keys.reminderMinutes); rescheduleLast() }
    }
    var overviewEnabled: Bool {
        didSet { save(overviewEnabled, for: Keys.overview); rescheduleLast() }
    }
    var overviewMinutes: Int {
        didSet { save(overviewMinutes, for: Keys.overviewMinutes); rescheduleLast() }
    }

    private enum Keys {
        static let taskReminders = "notifications.taskReminders"
        static let reminderMinutes = "notifications.reminderMinutes"
        static let overview = "notifications.overview"
        static let overviewMinutes = "notifications.overviewMinutes"
    }

    // iOS тримає максимум 64 заплановані сповіщення на застосунок
    private let maxTaskReminders = 56
    private let overviewDays = 7

    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard
    private var lastTasks: [TaskItem] = []
    private var rescheduleTask: Task<Void, Never>?

    init() {
        taskRemindersEnabled = defaults.bool(forKey: Keys.taskReminders)
        reminderMinutes = defaults.object(forKey: Keys.reminderMinutes) as? Int ?? 9 * 60
        overviewEnabled = defaults.bool(forKey: Keys.overview)
        overviewMinutes = defaults.object(forKey: Keys.overviewMinutes) as? Int ?? 8 * 60
    }

    // MARK: - Permissions

    func refreshStatus() async {
        authorizationStatus = await center.notificationSettings().authorizationStatus
    }

    /// Питає дозвіл, якщо ще не питали. true — можна слати сповіщення
    func requestAuthorization() async -> Bool {
        await refreshStatus()
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            await refreshStatus()
            return granted
        default:
            return false
        }
    }

    /// Вмикання перемикача: спершу дозвіл, і тільки потім вмикаємо
    func setTaskReminders(_ enabled: Bool) async {
        if enabled, !(await requestAuthorization()) { return }
        taskRemindersEnabled = enabled
    }

    func setOverview(_ enabled: Bool) async {
        if enabled, !(await requestAuthorization()) { return }
        overviewEnabled = enabled
    }

    // MARK: - Scheduling

    /// Перебудовує всі сповіщення під актуальний список задач
    func reschedule(for tasks: [TaskItem]) {
        lastTasks = tasks
        rescheduleTask?.cancel()
        rescheduleTask = Task {
            // Тестове сповіщення не чіпаємо
            let pending = await center.pendingNotificationRequests()
            center.removePendingNotificationRequests(
                withIdentifiers: pending.map(\.identifier).filter { !$0.hasPrefix("test-") })
            guard taskRemindersEnabled || overviewEnabled else { return }
            await refreshStatus()
            guard authorizationStatus == .authorized || authorizationStatus == .provisional else { return }

            var requests: [UNNotificationRequest] = []
            if taskRemindersEnabled { requests += taskReminderRequests(for: tasks) }
            if overviewEnabled { requests += overviewRequests(for: tasks) }

            for request in requests {
                guard !Task.isCancelled else { return }
                try? await center.add(request)
            }
        }
    }

    /// Після Log out — нагадування попереднього юзера не потрібні
    func clear() {
        rescheduleTask?.cancel()
        lastTasks = []
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    /// Для перевірки: сповіщення через 5 секунд
    func sendTestNotification() async {
        guard await requestAuthorization() else { return }
        let content = UNMutableNotificationContent()
        content.title = "Task Manager"
        content.body = "Notifications are working 👍"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: "test-\(UUID())", content: content, trigger: trigger))
    }

    // MARK: - Requests

    private func taskReminderRequests(for tasks: [TaskItem]) -> [UNNotificationRequest] {
        let now = Date.now
        let upcoming: [(TaskItem, Date)] = tasks
            .filter { $0.status != .done }
            .compactMap { task in
                guard let fireDate = date(task.dueDate, atMinutes: reminderMinutes), fireDate > now else { return nil }
                return (task, fireDate)
            }
            .sorted { $0.1 < $1.1 }

        return upcoming.prefix(maxTaskReminders).map { task, fireDate in
            let content = UNMutableNotificationContent()
            content.title = task.title
            content.body = "Due today · \(task.priority.title) priority · #\(task.tag)"
            content.sound = .default
            return UNNotificationRequest(identifier: "task-\(task.id)", content: content,
                                         trigger: trigger(for: fireDate))
        }
    }

    // Повторюване сповіщення не може мати різний текст, тому плануємо окреме на кожен з наступних 7 днів
    private func overviewRequests(for tasks: [TaskItem]) -> [UNNotificationRequest] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let open = tasks.filter { $0.status != .done }

        return (0..<overviewDays).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let fireDate = date(day, atMinutes: overviewMinutes), fireDate > .now else { return nil }

            let dueCount = open.filter { calendar.isDate($0.dueDate, inSameDayAs: day) }.count
            let overdueCount = open.filter { $0.dueDate < day }.count
            guard dueCount + overdueCount > 0 else { return nil }   // порожній день — не турбуємо

            let content = UNMutableNotificationContent()
            content.title = "Good morning ☀️"
            content.body = overdueCount > 0
                ? "Today: \(dueCount) \(dueCount == 1 ? "task" : "tasks") · \(overdueCount) overdue"
                : "Today: \(dueCount) \(dueCount == 1 ? "task" : "tasks")"
            content.sound = .default
            return UNNotificationRequest(identifier: "overview-\(offset)", content: content,
                                         trigger: trigger(for: fireDate))
        }
    }

    // MARK: - Helpers

    private func date(_ day: Date, atMinutes minutes: Int) -> Date? {
        Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day)
    }

    private func trigger(for date: Date) -> UNCalendarNotificationTrigger {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }

    private func rescheduleLast() {
        reschedule(for: lastTasks)
    }

    private func save(_ value: Any, for key: String) {
        defaults.set(value, forKey: key)
    }
}

// Без делегата iOS не показує банер, коли застосунок відкритий
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
