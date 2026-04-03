import Foundation
import SwiftData
import Observation

/// On-device store for full article text and AI-generated digests.
/// Uses SwiftData with its own ModelContainer — no server storage needed.
@Observable
final class ArticleFullTextStore {
    static let shared = ArticleFullTextStore()

    private let container: ModelContainer
    private var context: ModelContext

    private init() {
        do {
            container = try ModelContainer(for: ArticleFullText.self)
            context = ModelContext(container)
            context.autosaveEnabled = true
        } catch {
            fatalError("ArticleFullTextStore: failed to create SwiftData container: \(error)")
        }
    }

    // MARK: - Read

    func fetch(linkId: String) -> ArticleFullText? {
        var descriptor = FetchDescriptor<ArticleFullText>(
            predicate: #Predicate { $0.linkId == linkId }
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    func fetchAll() -> [ArticleFullText] {
        let descriptor = FetchDescriptor<ArticleFullText>(
            sortBy: [SortDescriptor(\.fetchedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func savedLinkIds() -> Set<String> {
        Set(fetchAll().map(\.linkId))
    }

    // MARK: - Write

    func save(linkId: String, rawText: String, digest: String, wordCount: Int) {
        if let existing = fetch(linkId: linkId) {
            context.delete(existing)
        }
        let entry = ArticleFullText(
            linkId: linkId,
            rawText: rawText,
            digest: digest,
            wordCount: wordCount
        )
        context.insert(entry)
        try? context.save()

        // Sync digest to Supabase so other devices can use it for podcast generation.
        // Fire-and-forget — local store is authoritative, this is best-effort.
        if SupabaseClient.shared.isAuthenticated {
            Task {
                try? await SupabaseClient.shared.updateLink(id: linkId, fields: ["digest": digest])
            }
        }
    }

    func delete(linkId: String) {
        if let existing = fetch(linkId: linkId) {
            context.delete(existing)
            try? context.save()
        }
    }
}
