import Foundation

struct User: Codable, Equatable {
    let id: Int
    let fullName: String
    let phone: String
    let email: String
}
