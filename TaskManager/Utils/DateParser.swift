import Foundation

// Розбирає дату з тексту задачі українською та англійською:
// "завтра о 18", "через 3 дні", "у пʼятницю", "25.12", "tomorrow at 9".
// Повертає пропозицію з готовою датою і підписом для чипа.
enum DateParser {
    struct Suggestion: Equatable {
        let date: Date
        let label: String   // як показати в чипі, напр. "завтра, 18:00"
    }

    static func parse(_ text: String, now: Date = .now,
                      calendar: Calendar = .current) -> Suggestion? {
        let lower = text.lowercased()
        guard !lower.isEmpty else { return nil }

        let time = parseTime(lower)
        guard let day = parseDay(lower, now: now, calendar: calendar) else { return nil }

        // Час чіпляємо на знайдений день; без часу лишаємо 9:00 за замовчуванням
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = time?.hour ?? 9
        components.minute = time?.minute ?? 0
        guard let date = calendar.date(from: components) else { return nil }

        return Suggestion(date: date, label: label(for: date, now: now, calendar: calendar))
    }

    // MARK: - День

    private static func parseDay(_ text: String, now: Date, calendar: Calendar) -> Date? {
        if contains(text, ["післязавтра", "day after tomorrow"]) {
            return calendar.date(byAdding: .day, value: 2, to: now)
        }
        if contains(text, ["завтра", "tomorrow"]) {
            return calendar.date(byAdding: .day, value: 1, to: now)
        }
        if contains(text, ["сьогодні", "today"]) {
            return now
        }
        if let days = relativeDays(text) {
            return calendar.date(byAdding: .day, value: days, to: now)
        }
        if let weekday = parseWeekday(text) {
            return nextWeekday(weekday, after: now, calendar: calendar)
        }
        if let date = parseNumericDate(text, now: now, calendar: calendar) {
            return date
        }
        return nil
    }

    // "через 3 дні" / "in 3 days"
    private static func relativeDays(_ text: String) -> Int? {
        for pattern in [#"через\s+(\d+)\s+д"#, #"in\s+(\d+)\s+day"#] {
            if let caps = capture(pattern, in: text, groups: 1), let days = caps[0] {
                return days
            }
        }
        return nil
    }

    // "25.12" або "25.12.2026"
    private static func parseNumericDate(_ text: String, now: Date, calendar: Calendar) -> Date? {
        guard let caps = capture(#"\b(\d{1,2})\.(\d{1,2})(?:\.(\d{2,4}))?\b"#, in: text, groups: 3),
              let day = caps[0], let month = caps[1],
              (1...31).contains(day), (1...12).contains(month) else { return nil }

        var components = DateComponents()
        components.day = day
        components.month = month
        if let year = caps[2] {
            components.year = year < 100 ? 2000 + year : year
        } else {
            // Без року беремо поточний, а якщо дата вже минула — наступний
            let year = calendar.component(.year, from: now)
            components.year = year
            if let date = calendar.date(from: components), date < calendar.startOfDay(for: now) {
                components.year = year + 1
            }
        }
        return calendar.date(from: components)
    }

    // MARK: - Час ("о 18", "о 18:30", "at 9", "9:00")

    private static func parseTime(_ text: String) -> (hour: Int, minute: Int)? {
        for pattern in [#"(?:о|at)\s+(\d{1,2})(?::(\d{2}))?"#, #"\b(\d{1,2}):(\d{2})\b"#] {
            guard let caps = capture(pattern, in: text, groups: 2),
                  let hour = caps[0], (0...23).contains(hour) else { continue }
            let minute = caps[1] ?? 0
            guard (0...59).contains(minute) else { continue }
            return (hour, minute)
        }
        return nil
    }

    // MARK: - Дні тижня

    private static let weekdays: [(names: [String], index: Int)] = [
        (["понеділок", "monday"], 2),
        (["вівторок", "tuesday"], 3),
        (["середу", "середа", "wednesday"], 4),
        (["четвер", "thursday"], 5),
        (["пʼятницю", "п'ятницю", "пятницю", "пʼятниця", "friday"], 6),
        (["суботу", "субота", "saturday"], 7),
        (["неділю", "неділя", "sunday"], 1),
    ]

    private static func parseWeekday(_ text: String) -> Int? {
        for day in weekdays where contains(text, day.names) {
            return day.index
        }
        return nil
    }

    // Найближчий майбутній день тижня (якщо сьогодні — беремо наступний тиждень)
    private static func nextWeekday(_ weekday: Int, after date: Date, calendar: Calendar) -> Date? {
        let current = calendar.component(.weekday, from: date)
        var diff = weekday - current
        if diff <= 0 { diff += 7 }
        return calendar.date(byAdding: .day, value: diff, to: date)
    }

    // MARK: - Підпис чипа

    private static func label(for date: Date, now: Date, calendar: Calendar) -> String {
        let dayLabel: String
        if calendar.isDate(date, inSameDayAs: now) {
            dayLabel = "Today"
        } else if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
                  calendar.isDate(date, inSameDayAs: tomorrow) {
            dayLabel = "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US")
            formatter.dateFormat = "d MMM"
            dayLabel = formatter.string(from: date)
        }

        let time = calendar.dateComponents([.hour, .minute], from: date)
        let timeLabel = String(format: "%02d:%02d", time.hour ?? 0, time.minute ?? 0)
        return "\(dayLabel), \(timeLabel)"
    }

    // MARK: - Дрібні хелпери

    private static func contains(_ text: String, _ words: [String]) -> Bool {
        words.contains { text.contains($0) }
    }

    // Числові групи першого збігу шаблону (nil, якщо група не спрацювала)
    private static func capture(_ pattern: String, in text: String, groups: Int) -> [Int?]? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
        else { return nil }

        return (1...groups).map { index in
            guard index < match.numberOfRanges,
                  let range = Range(match.range(at: index), in: text) else { return nil }
            return Int(text[range])
        }
    }
}
