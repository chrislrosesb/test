import Foundation

struct Link: Codable, Identifiable {
    let id: String
    var url: String
    var title: String?
    var description: String?
    var image: String?
    var favicon: String?
    var domain: String?
    var category: String?
    var tags: String?
    var stars: Int?
    var note: String?
    var summary: String?
    var digest: String?
    var status: String?
    var read: Bool?
    var isPrivate: Bool?
    var savedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, url, title, description, image, favicon
        case domain, category, tags, stars, note, summary, digest, status, read
        case isPrivate = "private"
        case savedAt = "saved_at"
    }
}
