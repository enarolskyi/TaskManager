import Foundation

// DTO для API, схеми з backend/main.py

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct RegisterRequest: Encodable {
    let fullName: String
    let phone: String
    let email: String
    let password: String
}

struct AuthResponse: Decodable {
    let token: String
    let user: User
}

// PATCH /me
struct UpdateProfileRequest: Encodable {
    let fullName: String
    let phone: String
    let email: String
}

// POST /me/password
struct ChangePasswordRequest: Encodable {
    let currentPassword: String
    let newPassword: String
}

// PATCH /settings — nil-поля не серіалізуються, тому оновлюються лише передані
struct SettingsUpdateRequest: Encodable {
    var theme: AppTheme?
    var timezone: String?
    var weekStart: WeekStart?
    var dailyGoal: Int?
    var weeklyGoal: Int?
}

struct NewTaskRequest: Encodable {
    let title: String
    let details: String
    let priority: TaskPriority
    let tag: String
    let dueDate: Date
}

// nil-поля не потрапляють у JSON, тож PATCH змінює лише передане
struct TaskUpdateRequest: Encodable {
    var title: String?
    var details: String?
    var status: TaskStatus?
    var priority: TaskPriority?
    var tag: String?
    var dueDate: Date?

    var isEmpty: Bool {
        title == nil && details == nil && status == nil
            && priority == nil && tag == nil && dueDate == nil
    }
}

// GET /stats
struct Stats: Decodable, Equatable {
    struct Day: Decodable, Equatable, Identifiable {
        let date: Date
        let completed: Int
        var id: Date { date }
    }

    let days: [Day]
    let completedToday: Int
    let completedThisWeek: Int
    let dailyGoal: Int
    let weeklyGoal: Int
    let streak: Int
    let totalCompleted: Int
    let todo: Int
    let inProgress: Int
    let overdue: Int
}
