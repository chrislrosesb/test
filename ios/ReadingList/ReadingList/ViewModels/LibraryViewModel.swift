import SwiftUI

@Observable
final class LibraryViewModel {
    var allLinks: [Link] = []
    var categories: [Category] = []
    var isLoading: Bool = false
    var errorMessage: String? = nil

    // Filters
    var selectedStatus: String? = nil
    var selectedCategory: String? = nil
    var sortByStars: Bool = false
    var searchQuery: String = ""

    var filteredLinks: [Link] {
        var result = allLinks

        if let status = selectedStatus {
            result = result.filter { $0.status == status }
        }
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        if sortByStars {
            result = result.sorted { ($0.stars ?? 0) > ($1.stars ?? 0) }
        }
        if !searchQuery.isEmpty {
            let tokens = searchQuery.lowercased().split(separator: " ").map(String.init)
            result = result.filter { link in
                let haystack = [link.title, link.description, link.note, link.domain, link.category, link.tags]
                    .compactMap { $0 }.joined(separator: " ").lowercased()
                return tokens.allSatisfy { haystack.contains($0) }
            }
        }
        return result
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            async let links = SupabaseClient.shared.fetchLinks()
            async let cats = SupabaseClient.shared.fetchCategories()
            (allLinks, categories) = try await (links, cats)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func refresh() async {
        errorMessage = nil
        do {
            async let links = SupabaseClient.shared.fetchLinks()
            async let cats = SupabaseClient.shared.fetchCategories()
            (allLinks, categories) = try await (links, cats)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Updates

    func updateStatus(link: Link, status: String?) async {
        let read = status == "done"
        var fields: [String: Any] = ["read": read]
        fields["status"] = status ?? NSNull()
        do {
            try await SupabaseClient.shared.updateLink(id: link.id.uuidString.lowercased(), fields: fields)
            if let idx = allLinks.firstIndex(where: { $0.id == link.id }) {
                allLinks[idx].status = status
                allLinks[idx].read = read
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateStars(link: Link, stars: Int) async {
        do {
            try await SupabaseClient.shared.updateLink(id: link.id.uuidString.lowercased(), fields: ["stars": stars])
            if let idx = allLinks.firstIndex(where: { $0.id == link.id }) {
                allLinks[idx].stars = stars
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateNote(link: Link, note: String) async {
        do {
            try await SupabaseClient.shared.updateLink(id: link.id.uuidString.lowercased(), fields: ["note": note])
            if let idx = allLinks.firstIndex(where: { $0.id == link.id }) {
                allLinks[idx].note = note.isEmpty ? nil : note
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(link: Link) async {
        do {
            try await SupabaseClient.shared.deleteLink(id: link.id.uuidString.lowercased())
            allLinks.removeAll { $0.id == link.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
