import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
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
        selectedCategory != nil || sortByStars
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
                let haystack = [link.title, link.description, link.note, link.summary, link.domain, link.category, link.tags]
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
        if let status {
            fields["status"] = status
        } else {
            fields["status"] = NSNull()
        }
        do {
            try await SupabaseClient.shared.updateLink(id: link.id, fields: fields)
            if let idx = allLinks.firstIndex(where: { $0.id == link.id }) {
                var updated = allLinks[idx]
                updated.status = status
                updated.read = read
                allLinks[idx] = updated  // Replace entire element to trigger @Observable
            }
        } catch {
            print("❌ updateStatus failed for \(link.id): \(error)")
            errorMessage = error.localizedDescription
        }
    }

    func updateStars(link: Link, stars: Int) async {
        do {
            try await SupabaseClient.shared.updateLink(id: link.id, fields: ["stars": stars])
            if let idx = allLinks.firstIndex(where: { $0.id == link.id }) {
                var updated = allLinks[idx]
                updated.stars = stars
                allLinks[idx] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateNote(link: Link, note: String) async {
        do {
            try await SupabaseClient.shared.updateLink(id: link.id, fields: ["note": note])
            if let idx = allLinks.firstIndex(where: { $0.id == link.id }) {
                var updated = allLinks[idx]
                updated.note = note.isEmpty ? nil : note
                allLinks[idx] = updated
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
                var updated = allLinks[idx]
                if let t = fields["title"] as? String { updated.title = t }
                if let n = fields["note"] as? String { updated.note = n.isEmpty ? nil : n }
                if let s = fields["summary"] as? String { updated.summary = s.isEmpty ? nil : s }
                if let ta = fields["tags"] as? String { updated.tags = ta.isEmpty ? nil : ta }
                if let c = fields["category"] as? String { updated.category = c.isEmpty ? nil : c }
                if let s = fields["status"] as? String {
                    updated.status = s
                    updated.read = (s == "done")
                }
                allLinks[idx] = updated
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
                if !result.summary.isEmpty { fields["summary"] = result.summary }
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

    // MARK: - AI Search (smart keyword matching)

    @available(iOS 26, *)
    func aiSearch(query: String) async {
        await smartSearch(query: query)
    }

    /// Smart search: extract meaningful keywords from natural language,
    /// then require ALL core terms to match (not just any one).
    func smartSearch(query: String) async {
        guard !query.isEmpty else { aiSearchResults = nil; return }

        let q = query.lowercased()

        // Strip common filler words to get the real search terms
        let stopWords: Set<String> = [
            "find", "me", "show", "get", "search", "for", "the", "a", "an",
            "that", "are", "is", "about", "with", "from", "my", "i", "stories",
            "story", "articles", "article", "links", "link", "ones", "some"
        ]

        let rawTokens = q.split(separator: " ").map(String.init)
        let keywords = rawTokens.filter { !stopWords.contains($0) && $0.count > 1 }

        // Detect intent modifiers
        let wantUnread = q.contains("unread") || q.contains("haven't read") || q.contains("not read")
        let wantDone = q.contains("done") || q.contains("finished") || q.contains("completed")
        let wantPodcast = q.contains("podcast")

        // Score each article: require at least one core keyword to match
        var scored: [(link: Link, score: Int)] = []

        for link in allLinks {
            let haystack = [link.title, link.description, link.note, link.summary, link.domain, link.category, link.tags]
                .compactMap { $0 }.joined(separator: " ").lowercased()

            // Count how many keywords match
            var matchCount = 0
            for keyword in keywords {
                if haystack.contains(keyword) { matchCount += 1 }
            }

            // Must match at least half of the non-modifier keywords, minimum 1
            let coreKeywords = keywords.filter { !["unread", "done", "finished", "podcast", "podcasts"].contains($0) }
            let requiredMatches = max(1, (coreKeywords.count + 1) / 2)

            let coreMatches = coreKeywords.filter { haystack.contains($0) }.count
            guard coreMatches >= requiredMatches else { continue }

            var score = coreMatches * 10

            // Boost/penalize by intent
            if wantPodcast {
                if haystack.contains("podcast") { score += 5 } else { continue }
            }
            if wantUnread && link.status == "done" { continue }
            if wantDone && link.status != "done" { continue }

            // Bonus for title matches (more relevant than tag/note matches)
            let titleLower = (link.title ?? "").lowercased()
            for keyword in coreKeywords {
                if titleLower.contains(keyword) { score += 5 }
            }

            scored.append((link, score))
        }

        aiSearchResults = scored.sorted { $0.score > $1.score }.prefix(20).map(\.link)
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
