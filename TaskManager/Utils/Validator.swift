import Foundation

enum Validator {

    static func isValidFullName(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespaces).count >= 2
    }

    // Рахуємо лише цифри, щоб приймати формат "+380 (67) 123-45-67"
    static func isValidPhone(_ value: String) -> Bool {
        let digits = value.filter(\.isNumber)
        return (10...15).contains(digits.count)
    }

    static func isValidEmail(_ value: String) -> Bool {
        let pattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        return value.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    // Ті самі правила, що й на бекенді
    static func isValidPassword(_ value: String) -> Bool {
        value.count >= 8
            && value.contains(where: \.isUppercase)
            && value.contains(where: \.isNumber)
    }
}
