import Foundation

struct Recipient: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let slug: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, slug, createdAt = "created_at"
    }
}
