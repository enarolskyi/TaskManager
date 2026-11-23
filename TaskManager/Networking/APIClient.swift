import Foundation

enum APIError: LocalizedError {
    case server(message: String)
    case unauthorized
    case network
    case decoding
    case cancelled   // запит скасовано (напр. перемкнули таб) — не помилка, ігноруємо

    var errorDescription: String? {
        switch self {
        case .server(let message): message
        case .unauthorized: "Session expired. Please log in again"
        case .network: "Can't reach the server. Is the backend running?"
        case .decoding: "Unexpected server response"
        case .cancelled: nil
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    // Куди ходить застосунок, залежить від вибору Cloud / Local Mac у More → Server.
    // Обчислюється на кожен запит, тож перемикання діє одразу.
    static let macIP = "192.168.0.226"   // IP мака у Wi-Fi: ipconfig getifaddr en0

    private var baseURL: URL {
        switch ServerEnvironment.current {
        case .cloud:
            return URL(string: ServerEnvironment.cloudURL) ?? Self.localURL
        case .local:
            return Self.localURL
        }
    }

    private static var localURL: URL {
        // Симулятор працює на самому маку (127.0.0.1), реальний пристрій шукає мак у Wi-Fi
        #if targetEnvironment(simulator)
        return URL(string: "http://127.0.0.1:8000")!
        #else
        return URL(string: "http://\(macIP):8000")!
        #endif
    }

    // Довший таймаут під холодний старт Render (сервіс прокидається 30–60 с),
    // waitsForConnectivity — чекати мережу, а не падати одразу
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 90
        config.timeoutIntervalForResource = 120
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    // TODO: перенести токен у Keychain
    var token: String? {
        get { UserDefaults.standard.string(forKey: "authToken") }
        set { UserDefaults.standard.set(newValue, forKey: "authToken") }
    }

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    // API використовує snake_case
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        // Дати двох видів: "2026-11-15" (due_date) і "2026-11-15T09:30:00+00:00" (completed_at)
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "yyyy-MM-dd"
            dayFormatter.locale = Locale(identifier: "en_US_POSIX")
            if let date = dayFormatter.date(from: value) { return date }
            if let date = ISO8601DateFormatter().date(from: value) { return date }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(value)")
        }
        return decoder
    }()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .formatted(APIClient.dateFormatter)
        return encoder
    }()

    // MARK: - Public

    func get<T: Decodable>(_ path: String) async throws -> T {
        try decode(try await perform("GET", path, body: nil))
    }

    func post<T: Decodable>(_ path: String, body: any Encodable) async throws -> T {
        try decode(try await perform("POST", path, body: body))
    }

    func patch<T: Decodable>(_ path: String, body: any Encodable) async throws -> T {
        try decode(try await perform("PATCH", path, body: body))
    }

    /// Для 204 No Content
    func postNoContent(_ path: String, body: (any Encodable)? = nil) async throws {
        _ = try await perform("POST", path, body: body)
    }

    func delete(_ path: String) async throws {
        _ = try await perform("DELETE", path, body: nil)
    }

    // MARK: - Private

    private func perform(_ method: String, _ path: String, body: (any Encodable)?) async throws -> Data {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = try encoder.encode(body)
        }

        print("➡️ \(method) \(path)")
        if let body = request.httpBody {
            print("   body: \(Self.prettyJSON(body))")
        }

        // GET безпечно повторити: якщо сервер ще прокидається, перша спроба може не дійти
        let maxAttempts = method == "GET" ? 2 : 1
        for attempt in 1...maxAttempts {
            do {
                return try await send(request, path: path)
            } catch APIError.network where attempt < maxAttempts {
                try? await Task.sleep(for: .seconds(2))   // дати сервісу прокинутись і повторити
                continue
            }
        }
        throw APIError.network   // недосяжно, але потрібне компілятору
    }

    private func send(_ request: URLRequest, path: String) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw APIError.cancelled
        } catch let error as URLError where error.code == .cancelled {
            // Запит скасовано (перемкнули таб) — це не збій сервера
            throw APIError.cancelled
        } catch {
            print("❌ Network error: \(error.localizedDescription)")
            throw APIError.network
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.network }
        print("⬅️ \(http.statusCode) \(path)")
        if !data.isEmpty {
            print("   response: \(Self.prettyJSON(data))")
        }

        switch http.statusCode {
        case 200..<300:
            return data
        case 401 where !path.hasPrefix("/auth/"):
            throw APIError.unauthorized
        default:
            throw APIError.server(message: Self.errorMessage(from: data))
        }
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            print("❌ Decoding error: \(error)")
            throw APIError.decoding
        }
    }

    /// JSON для логів, чутливі поля маскуються
    private static func prettyJSON(_ data: Data) -> String {
        guard var object = try? JSONSerialization.jsonObject(with: data) else {
            return String(decoding: data, as: UTF8.self)
        }
        if var dict = object as? [String: Any] {
            for key in ["password", "current_password", "new_password", "token"] where dict[key] != nil {
                dict[key] = "***"
            }
            object = dict
        }
        guard let pretty = try? JSONSerialization.data(withJSONObject: object,
                                                       options: [.prettyPrinted, .sortedKeys]) else {
            return String(decoding: data, as: UTF8.self)
        }
        return String(decoding: pretty, as: UTF8.self)
    }

    // FastAPI повертає detail рядком або списком (422 від Pydantic)
    private static func errorMessage(from data: Data) -> String {
        struct StringDetail: Decodable { let detail: String }
        struct ListDetail: Decodable {
            struct Item: Decodable { let msg: String }
            let detail: [Item]
        }

        if let error = try? JSONDecoder().decode(StringDetail.self, from: data) {
            return error.detail
        }
        if let error = try? JSONDecoder().decode(ListDetail.self, from: data),
           let first = error.detail.first {
            return first.msg.replacingOccurrences(of: "Value error, ", with: "")
        }
        return "Something went wrong"
    }
}
