import Foundation

struct Category: Codable, Identifiable {
    let name: String
    let sortOrder: Int?

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name
        case sortOrder = "sort_order"
    }
}
