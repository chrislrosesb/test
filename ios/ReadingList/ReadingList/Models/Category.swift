import Foundation

struct Category: Codable, Identifiable {
    let id: Int
    let name: String
    let sortOrder: Int?

    enum CodingKeys: String, CodingKey {
        case id, name
        case sortOrder = "sort_order"
    }
}
