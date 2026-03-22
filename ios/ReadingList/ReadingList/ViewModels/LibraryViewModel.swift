import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

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

    // Enrich All progress
    var enrichAllProgress: (current: Int, total: Int)? = nil
    var isEnrichingAll: Bool = false

    // AI Search
    var aiSearchResults: [Link]? = nil

    var hasActiveFilters: Bool {
        selectedStatus != nil || selectedCategory != nil || sortByStars
    }

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
            allLinks = try await SupabaseClient.shared.fetchLinks()
        } catch is CancellationError {
            // Silently ignore — user navigated away
        } catch let urlError as URLError where urlError.code == .cancelled {
            // Silently ignore — request cancelled
        } catch {
            errorMessage = "Links: \(error.localizedDescription)"
        }
        do {
            categories = try await SupabaseClient.shared.fetchCategories()
        } catch is CancellationError {
        } catch let urlError as URLError where urlError.code == .cancelled {
        } catch {
            let catError = "Categories: \(error.localizedDescription)"
            errorMessage = errorMessage == nil ? catError : errorMessage! + "\n" + catError
        }
        isLoading = false
    }

    func refresh() async {
        await load()
    }

    // MARK: - Updates

    func updateStatus(link: Link, status: String?) async {
        let read = status == "done"
        var fields: [String: Any] = ["read": read]
        fields["status"] = status ?? NSNull()
        do {
            try await SupabaseClient.shared.updateLink(id: link.id, fields: fields)
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
            try await SupabaseClient.shared.updateLink(id: link.id, fields: ["stars": stars])
            if let idx = allLinks.firstIndex(where: { $0.id == link.id }) {
                allLinks[idx].stars = stars
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateNote(link: Link, note: String) async {
        do {
            try await SupabaseClient.shared.updateLink(id: link.id, fields: ["note": note])
            if let idx = allLinks.firstIndex(where: { $0.id == link.id }) {
                allLinks[idx].note = note.isEmpty ? nil : note
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateEnrich(link: Link, fields: [String: Any]) async {
        guard !fields.isEmpty else { return }
        do {
            try await SupabaseClient.shared.updateLink(id: link.id, fields: fields)
            if let idx = allLinks.firstIndex(where: { $0.id == link.id }) {
                if let t = fields["title"] as? String { allLinks[idx].title = t }
                if let n = fields["note"] as? String { allLinks[idx].note = n.isEmpty ? nil : n }
                if let ta = fields["tags"] as? String { allLinks[idx].tags = ta.isEmpty ? nil : ta }
                if let c = fields["category"] as? String { allLinks[idx].category = c.isEmpty ? nil : c }
                if let s = fields["status"] as? String {
                    allLinks[idx].status = s
                    allLinks[idx].read = (s == "done")
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Enrich All (batch)

    var unenrichedLinks: [Link] {
        // Articles that have no AI-generated note (note is nil or empty)
        allLinks.filter { $0.note == nil || ($0.note?.isEmpty == true) }
    }

    @available(iOS 26, *)
    func enrichAll() async {
        #if canImport(FoundationModels)
        let targets = unenrichedLinks
        guard !targets.isEmpty else { return }

        isEnrichingAll = true
        enrichAllProgress = (current: 0, total: targets.count)
        let categoryNames = categories.map(\.name)

        for (i, link) in targets.enumerated() {
            enrichAllProgress = (current: i + 1, total: targets.count)
            do {
                let result = try await EnrichEngine.enrich(link: link, categories: categoryNames)
                var fields: [String: Any] = [:]
                if result.cleanTitle != (link.title ?? "") { fields["title"] = result.cleanTitle }
                if !result.summary.isEmpty { fields["note"] = result.summary }
                if !result.tags.isEmpty { fields["tags"] = result.tags }
                if !result.category.isEmpty { fields["category"] = result.category }
                if !result.status.isEmpty {
                    fields["status"] = result.status
                    fields["read"] = (result.status == "done")
                }
                await updateEnrich(link: link, fields: fields)
            } catch {
                // Skip failed articles, continue batch
                continue
            }
        }

        isEnrichingAll = false
        enrichAllProgress = nil
        #endif
    }

    // MARK: - Related Articles

    func relatedArticles(for link: Link, limit: Int = 5) -> [Link] {
        let currentTags = Set((link.tags ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() })
        let currentCategory = link.category?.lowercased()
        let currentDomain = link.domain?.lowercased()

        var scored: [(link: Link, score: Int)] = []

        for other in allLinks where other.id != link.id {
            var score = 0

            // Same category: +3
            if let cat = other.category?.lowercased(), cat == currentCategory { score += 3 }

            // Shared tags: +2 each
            let otherTags = Set((other.tags ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() })
            score += currentTags.intersection(otherTags).count * 2

            // Same domain: +1
            if let dom = other.domain?.lowercased(), dom == currentDomain { score += 1 }

            if score > 0 { scored.append((other, score)) }
        }

        return scored.sorted { $0.score > $1.score }.prefix(limit).map(\.link)
    }

    // MARK: - Duplicate Detection

    func findDuplicates() -> [(Link, Link)] {
        var dupes: [(Link, Link)] = []
        let normalized = allLinks.map { (link: $0, url: normalizeURL($0.url)) }

        for i in 0..<normalized.count {
            for j in (i+1)..<normalized.count {
                if normalized[i].url == normalized[j].url {
                    dupes.append((normalized[i].link, normalized[j].link))
                }
            }
        }
        return dupes
    }

    func duplicatesOf(_ link: Link) -> [Link] {
        let norm = normalizeURL(link.url)
        return allLinks.filter { $0.id != link.id && normalizeURL($0.url) == norm }
    }

    private func normalizeURL(_ url: String) -> String {
        var u = url.lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
        if u.hasSuffix("/") { u = String(u.dropLast()) }
        return u
    }

    // MARK: - AI Search

    @available(iOS 26, *)
    func aiSearch(query: String) async {
        #if canImport(FoundationModels)
        guard !query.isEmpty else { aiSearchResults = nil; return }

        // Step 1: Ask AI to expand the natural language query into search keywords
        let prompt = """
        The user wants to search their reading list library. Convert their natural language query into simple search keywords.

        User query: "\(query)"

        Return ONLY a comma-separated list of lowercase search keywords/terms that would match relevant articles. Include synonyms and related terms. No explanation, just the keywords.

        Example: "articles about AI I haven't read" → "ai, artificial intelligence, machine learning, llm, gpt, neural"
        Example: "design tutorials" → "design, ui, ux, css, frontend, tutorial, guide, how to"
        """

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            var text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

            // Strip markdown if present
            if text.hasPrefix("```") { text = text.replacingOccurrences(of: "```", with: "") }
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)

            // Parse keywords
            let keywords = text.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }

            guard !keywords.isEmpty else {
                aiSearchResults = []
                return
            }

            // Step 2: Score each article by keyword matches
            var scored: [(link: Link, score: Int)] = []
            for link in allLinks {
                let haystack = [link.title, link.description, link.note, link.domain, link.category, link.tags]
                    .compactMap { $0 }.joined(separator: " ").lowercased()

                var score = 0
                for keyword in keywords {
                    if haystack.contains(keyword) { score += 1 }
                }

                // Also check status-based queries
                if query.lowercased().contains("unread") || query.lowercased().contains("haven't read") {
                    if link.status != "done" { score += 1 }
                }
                if query.lowercased().contains("done") || query.lowercased().contains("finished") {
                    if link.status == "done" { score += 2 }
                }

                if score > 0 { scored.append((link, score)) }
            }

            aiSearchResults = scored.sorted { $0.score > $1.score }.prefix(20).map(\.link)
        } catch {
            // Fallback: do simple keyword search with the original query
            let tokens = query.lowercased().split(separator: " ").map(String.init)
            aiSearchResults = allLinks.filter { link in
                let haystack = [link.title, link.description, link.note, link.domain, link.category, link.tags]
                    .compactMap { $0 }.joined(separator: " ").lowercased()
                return tokens.contains { haystack.contains($0) }
            }
        }
        #else
        // No FoundationModels: fall back to keyword search
        let tokens = query.lowercased().split(separator: " ").map(String.init)
        aiSearchResults = allLinks.filter { link in
            let haystack = [link.title, link.description, link.note, link.domain, link.category, link.tags]
                .compactMap { $0 }.joined(separator: " ").lowercased()
            return tokens.contains { haystack.contains($0) }
        }
        #endif
    }

    func clearAISearch() {
        aiSearchResults = nil
    }

    // MARK: - Delete

    func delete(link: Link) async {
        do {
            try await SupabaseClient.shared.deleteLink(id: link.id)
            allLinks.removeAll { $0.id == link.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
