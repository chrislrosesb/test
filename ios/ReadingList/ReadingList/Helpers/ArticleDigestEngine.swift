import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Generates a rich ~200-word digest from article full text using Foundation Models.
/// The digest is optimised for Knowledge Synthesis — more analytical than the Enrich summary.
enum ArticleDigestEngine {

    @available(iOS 26, *)
    static func generateDigest(for link: Link, rawText: String) async throws -> String {
        #if canImport(FoundationModels)
        let excerpt = String(rawText.prefix(4000))

        var metadata = "Title: \(link.title ?? link.url)\nDomain: \(link.domain ?? "unknown")"
        if let tags = link.tags, !tags.isEmpty { metadata += "\nTags: \(tags)" }
        if let note = link.note, !note.isEmpty { metadata += "\nMy personal note: \(note)" }
        if let summary = link.summary, !summary.isEmpty {
            metadata += "\nExisting AI summary: \(summary)"
        }

        let prompt = """
        \(metadata)

        Article text (excerpt):
        \(excerpt)

        Write a 150-200 word digest of this article for future reference. Include:
        - The core argument or finding (be specific, not vague)
        - Any surprising, counterintuitive, or nuanced point worth remembering
        - Why it's relevant to the topics and tags noted above
        - A connection to the personal note if one exists

        Write in third person ("This article argues...", "The author shows..."). Be concrete — name specific ideas, not just themes. No filler phrases like "This article explores" or "It is important to note".
        """

        let session = LanguageModelSession()
        let response = try await session.respond(to: prompt)
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        #else
        return ""
        #endif
    }
}
