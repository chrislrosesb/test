import Foundation
import SwiftData

@Model
final class ArticleFullText {
    var linkId: String
    var rawText: String
    var digest: String
    var wordCount: Int
    var fetchedAt: Date

    init(linkId: String, rawText: String, digest: String, wordCount: Int) {
        self.linkId = linkId
        self.rawText = rawText
        self.digest = digest
        self.wordCount = wordCount
        self.fetchedAt = Date()
    }
}
