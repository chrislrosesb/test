import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

struct DiscoverResult: Identifiable {
    let id = UUID()
    let title: String
    let snippet: String
    let url: String
    let source: String
    let image: String?
}

struct DuckDuckGoResponse: Codable {
    let relatedTopics: [RelatedTopic]

    enum CodingKeys: String, CodingKey {
        case relatedTopics = "RelatedTopics"
    }
}

struct RelatedTopic: Codable {
    let text: String?
    let firstURL: String?
    let icon: IconData?

    enum CodingKeys: String, CodingKey {
        case text = "Text"
        case firstURL = "FirstURL"
        case icon = "Icon"
    }
}

struct IconData: Codable {
    let URL: String?

    enum CodingKeys: String, CodingKey {
        case URL
    }
}

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
    var selectedTag: String? = nil
    var sortByStars: Bool = false
    var searchQuery: String = ""

    // Enrich All progress
    var enrichAllProgress: (current: Int, total: Int)? = nil
    var isEnrichingAll: Bool = false

    // AI Search
    var aiSearchResults: [Link]? = nil

    // Discover Similar
    enum DiscoverPhase {
        case idle
        case extracting
        case searching
        case ready([DiscoverResult])
        case error(String)
    }
    var discoverPhase: DiscoverPhase = .idle
    var discoverThemes: [String] = []

    var hasActiveFilters: Bool {
        selectedCategory != nil || selectedTag != nil || sortByStars
    }

    // MARK: - AI Insights

    /// Articles saved in the last 24 hours.
    var todaysLinks: [Link] {
        let cutoff = Date().addingTimeInterval(-86400)
        return allLinks.filter { ($0.savedAt ?? .distantPast) >= cutoff }
    }

    /// Numbered list of today's saves for the Digest prompt (max 20, empty string if none).
    /// Includes digest when available, otherwise summary or note, for richer AI analysis.
    var todaysSavedContext: String {
        let recent = todaysLinks.prefix(20)
        guard !recent.isEmpty else { return "" }
        return recent.enumerated().map { i, link in
            var parts = "\(i + 1). \"\(link.title ?? link.url)\" (\(link.domain ?? "unknown"))"
            if let ft = ArticleFullTextStore.shared.fetch(linkId: link.id), !ft.digest.isEmpty {
                parts += "\n   \(ft.digest)"
            } else if let summary = link.summary, !summary.isEmpty {
                parts += "\n   Summary: \(summary)"
            } else if let note = link.note, !note.isEmpty {
                parts += "\n   My note: \(note)"
            }
            return parts
        }.joined(separator: "\n\n")
    }

    /// Compact pre-aggregated stats string for the Insights prompt.
    var libraryStatsContext: String {
        let total = allLinks.count
        guard total > 0 else { return "Library is empty." }

        let toRead   = allLinks.filter { $0.status == "to-read" }.count
        let toDo     = allLinks.filter { $0.status == "to-try" }.count
        let done     = allLinks.filter { $0.status == "done" }.count
        let unsorted = total - toRead - toDo - done
        let starred  = allLinks.filter { ($0.stars ?? 0) >= 4 }.count

        let topTags = tagCounts.prefix(10)
            .map { "\($0.tag) (\($0.count))" }
            .joined(separator: ", ")

        var catCounts: [String: Int] = [:]
        for link in allLinks { if let c = link.category { catCounts[c, default: 0] += 1 } }
        let topCats = catCounts.sorted { $0.value > $1.value }.prefix(6)
            .map { "\($0.key): \($0.value)" }.joined(separator: ", ")

        var domCounts: [String: Int] = [:]
        for link in allLinks { if let d = link.domain { domCounts[d, default: 0] += 1 } }
        let topDomains = domCounts.sorted { $0.value > $1.value }.prefix(5)
            .map { "\($0.key) (\($0.value))" }.joined(separator: ", ")

        let oldest = allLinks.compactMap(\.savedAt).min()
        let ageStr: String
        if let oldest {
            let days = Calendar.current.dateComponents([.day], from: oldest, to: Date()).day ?? 0
            ageStr = days < 14 ? "\(days) days" : "\(days / 7) weeks"
        } else { ageStr = "unknown" }

        return """
        Total: \(total) articles saved over \(ageStr)
        Status: \(toRead) to-read, \(toDo) to-try, \(done) done, \(unsorted) unsorted
        Starred (4-5 stars): \(starred)
        Not yet enriched: \(unenrichedLinks.count)
        Top tags: \(topTags.isEmpty ? "none" : topTags)
        Categories: \(topCats.isEmpty ? "none" : topCats)
        Top domains: \(topDomains.isEmpty ? "none" : topDomains)
        """
    }

    /// Articles with non-empty notes saved within the given date range, newest first.
    func notedLinks(from start: Date, to end: Date) -> [Link] {
        allLinks.filter {
            guard let note = $0.note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
            let saved = $0.savedAt ?? .distantPast
            return saved >= start && saved <= end
        }.sorted { ($0.savedAt ?? .distantPast) > ($1.savedAt ?? .distantPast) }
    }

    /// Prompt context for Notes Review: title, domain, note, and digest (or summary as fallback).
    /// Capped at 20 articles to stay within Foundation Models context.
    func notesContext(from start: Date, to end: Date) -> String {
        let links = notedLinks(from: start, to: end).prefix(20)
        guard !links.isEmpty else { return "" }
        return links.enumerated().map { i, link in
            var parts = "\(i + 1). \"\(link.title ?? link.url)\" (\(link.domain ?? "unknown"))"
            parts += "\n   My note: \(link.note!.trimmingCharacters(in: .whitespacesAndNewlines))"
            if let ft = ArticleFullTextStore.shared.fetch(linkId: link.id), !ft.digest.isEmpty {
                parts += "\n   Article digest: \(ft.digest)"
            } else if let summary = link.summary, !summary.isEmpty {
                parts += "\n   Summary: \(summary)"
            }
            return parts
        }.joined(separator: "\n\n")
    }

    var tagCounts: [(tag: String, count: Int)] {
        var counts: [String: Int] = [:]
        for link in allLinks {
            guard let tags = link.tags else { continue }
            for raw in tags.split(separator: ",") {
                let tag = raw.trimmingCharacters(in: .whitespaces).lowercased()
                guard !tag.isEmpty else { continue }
                counts[tag, default: 0] += 1
            }
        }
        return counts.map { (tag: $0.key, count: $0.value) }
                     .sorted { $0.count > $1.count || ($0.count == $1.count && $0.tag < $1.tag) }
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
            // Refetch all data to guarantee UI is in sync
            allLinks = (try? await SupabaseClient.shared.fetchLinks()) ?? allLinks
        } catch {
            print("❌ updateStatus failed for \(link.id): \(error)")
            errorMessage = error.localizedDescription
        }
    }

    func updateStars(link: Link, stars: Int) async {
        do {
            try await SupabaseClient.shared.updateLink(id: link.id, fields: ["stars": stars])
            allLinks = (try? await SupabaseClient.shared.fetchLinks()) ?? allLinks
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateNote(link: Link, note: String) async {
        do {
            try await SupabaseClient.shared.updateLink(id: link.id, fields: ["note": note])
            allLinks = (try? await SupabaseClient.shared.fetchLinks()) ?? allLinks
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateTitle(link: Link, title: String) async {
        do {
            try await SupabaseClient.shared.updateLink(id: link.id, fields: ["title": title])
            allLinks = (try? await SupabaseClient.shared.fetchLinks()) ?? allLinks
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateTags(link: Link, tags: String?) async {
        var fields: [String: Any] = [:]
        if let tags, !tags.isEmpty { fields["tags"] = tags }
        else { fields["tags"] = NSNull() }
        do {
            try await SupabaseClient.shared.updateLink(id: link.id, fields: fields)
            allLinks = (try? await SupabaseClient.shared.fetchLinks()) ?? allLinks
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateCategory(link: Link, category: String?) async {
        var fields: [String: Any] = [:]
        if let category {
            fields["category"] = category
        } else {
            fields["category"] = NSNull()
        }
        do {
            try await SupabaseClient.shared.updateLink(id: link.id, fields: fields)
            allLinks = (try? await SupabaseClient.shared.fetchLinks()) ?? allLinks
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateEnrich(link: Link, fields: [String: Any]) async {
        guard !fields.isEmpty else { return }
        do {
            try await SupabaseClient.shared.updateLink(id: link.id, fields: fields)
            allLinks = (try? await SupabaseClient.shared.fetchLinks()) ?? allLinks
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Enrich All (batch)

    var unenrichedLinks: [Link] {
        // Articles that have no AI-generated summary AND no user note
        allLinks.filter {
            ($0.summary == nil || $0.summary?.isEmpty == true) &&
            ($0.note == nil || $0.note?.isEmpty == true)
        }
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
            let fullTextDigest = ArticleFullTextStore.shared.fetch(linkId: link.id)?.digest
            let haystack = [link.title, link.description, link.note, link.summary, link.domain, link.category, link.tags, fullTextDigest]
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

    // MARK: - Discover Similar

    func discoverSimilar(fromRecap recap: String) async {
        guard !recap.isEmpty else { return }
        discoverPhase = .extracting

        // Extract themes from Notes Review recap using Foundation Models
        do {
            if #available(iOS 26, *) {
                let themes = try await extractThemesFromRecap(recap)
                discoverThemes = themes
                discoverPhase = .searching
                await searchInternet(for: themes)
            } else {
                discoverPhase = .error("Requires iOS 26+")
            }
        } catch {
            discoverPhase = .error(error.localizedDescription)
        }
    }

    @available(iOS 26, *)
    private func extractThemesFromRecap(_ recap: String) async throws -> [String] {
        let session = LanguageModelSession()
        let prompt = """
        From this reading recap, extract 5-8 key themes or topics of interest as a comma-separated list.
        Just the topics, nothing else.

        Recap:
        \(recap)
        """
        let response = try await session.respond(to: prompt)
        let themes = response.content.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces).lowercased() }
        return Array(themes.prefix(8))
    }

    private func searchInternet(for themes: [String]) async {
        let query = themes.joined(separator: " ")
        do {
            let results = try await searchDuckDuckGo(query: query)
            discoverPhase = .ready(results)
        } catch {
            discoverPhase = .error("Search failed: \(error.localizedDescription)")
        }
    }

    private func searchDuckDuckGo(query: String) async throws -> [DiscoverResult] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://api.duckduckgo.com/?q=\(encoded)&format=json&no_redirect=1"
        guard let url = URL(string: urlString) else { throw NSError(domain: "Invalid URL", code: -1) }

        let (data, _) = try await URLSession.shared.data(from: url)
        let decoder = JSONDecoder()
        let response = try decoder.decode(DuckDuckGoResponse.self, from: data)

        var results: [DiscoverResult] = []

        // Use related topics or results if available
        if !response.relatedTopics.isEmpty {
            for item in response.relatedTopics.prefix(12) {
                guard let result = parseTopicResult(item) else { continue }
                results.append(result)
            }
        }

        return results
    }

    private func parseTopicResult(_ topic: RelatedTopic) -> DiscoverResult? {
        let text = topic.text ?? ""
        let url = topic.firstURL ?? ""
        guard !url.isEmpty, !text.isEmpty else { return nil }

        let title = extractTitle(from: text)
        let snippet = extractSnippet(from: text)

        return DiscoverResult(
            title: title,
            snippet: snippet,
            url: url,
            source: extractDomain(from: url),
            image: topic.icon?.URL
        )
    }

    private func extractTitle(from text: String) -> String {
        if let dashIndex = text.firstIndex(of: "-") {
            return String(text[..<dashIndex]).trimmingCharacters(in: .whitespaces)
        }
        return String(text.prefix(60))
    }

    private func extractSnippet(from text: String) -> String {
        if let dashIndex = text.firstIndex(of: "-") {
            let snippet = String(text[text.index(after: dashIndex)...]).trimmingCharacters(in: .whitespaces)
            return String(snippet.prefix(150))
        }
        return String(text.prefix(150))
    }

    private func extractDomain(from url: String) -> String {
        if let components = URLComponents(string: url), let host = components.host {
            return host.replacingOccurrences(of: "www.", with: "")
        }
        return "web"
    }

    func addDiscoveredArticle(_ result: DiscoverResult) async {
        do {
            let link = Link(
                id: UUID().uuidString,
                url: result.url,
                title: result.title,
                description: result.snippet,
                image: result.image,
                favicon: nil,
                domain: result.source,
                category: nil,
                tags: discoverThemes.joined(separator: ", "),
                stars: nil,
                note: nil,
                summary: result.snippet,
                status: "to-read",
                read: false,
                isPrivate: false,
                savedAt: Date()
            )
            try await SupabaseClient.shared.insertLink(link)
            allLinks.insert(link, at: 0)
        } catch {
            errorMessage = "Failed to add article: \(error.localizedDescription)"
        }
    }

    func clearDiscoverSimilar() {
        discoverPhase = .idle
        discoverThemes = []
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
