import Foundation
import SwiftUI

// MARK: - Question types

enum ReflectionQuestionType: String, CaseIterable, Codable {
    case action     // "What would you actually try based on this?"
    case connection // "How does this connect to your current work or life?"
    case surprise   // "What here contradicted your expectations?"
    case opinion    // "Do you agree with the author? Where do they get it wrong?"
    case recall     // "What's the one thing you'd want to remember in a year?"
}

// MARK: - Store

@Observable
final class ReflectionStore {
    static let shared = ReflectionStore()

    // Pending reflections: linkId → date queued
    private(set) var pendingQueue: [String: Date] = [:]
    // Set of linkIds that have been reflected on
    private(set) var reflectedIds: Set<String> = []
    // Set of linkIds the user has dismissed from suggestions (never show again)
    private(set) var dismissedFromSuggestions: Set<String> = []
    // Streak tracking
    private(set) var currentStreak: Int = 0
    private(set) var lastReflectionDate: Date?
    // Question rotation
    private(set) var lastQuestionType: ReflectionQuestionType = .recall

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let pending   = "reflect.pending"
        static let reflected = "reflect.reflected"
        static let dismissed = "reflect.dismissed"
        static let streak    = "reflect.streak"
        static let lastDate  = "reflect.lastDate"
        static let lastType  = "reflect.lastType"
    }

    private init() { load() }

    // MARK: - Pending queue

    func addToPending(linkId: String) {
        pendingQueue[linkId] = Date()
        save()
    }

    func removeFromPending(linkId: String) {
        pendingQueue.removeValue(forKey: linkId)
        save()
    }

    /// Active pending: queued within the last 72 hours
    func activePendingIds() -> Set<String> {
        let cutoff = Date().addingTimeInterval(-72 * 3600)
        return Set(pendingQueue.filter { $0.value > cutoff }.keys)
    }

    func pendingLinks(from allLinks: [Link]) -> [Link] {
        let active = activePendingIds()
        return allLinks
            .filter { active.contains($0.id) }
            .sorted { (pendingQueue[$0.id] ?? .distantPast) > (pendingQueue[$1.id] ?? .distantPast) }
    }

    var pendingCount: Int { activePendingIds().count }

    func isPending(_ linkId: String) -> Bool { activePendingIds().contains(linkId) }

    func queuedAt(linkId: String) -> Date? { pendingQueue[linkId] }

    // MARK: - Reflection completion

    func dismissFromSuggestions(linkId: String) {
        dismissedFromSuggestions.insert(linkId)
        save()
    }

    func isDismissed(_ linkId: String) -> Bool { dismissedFromSuggestions.contains(linkId) }

    func markReflected(linkId: String) {
        reflectedIds.insert(linkId)
        removeFromPending(linkId: linkId)
        updateStreak()
        save()
    }

    func isReflected(_ linkId: String) -> Bool { reflectedIds.contains(linkId) }

    // MARK: - Question rotation

    /// Pick the next question type — rotates and uses article metadata to prefer a fitting type
    func nextQuestionType(for link: Link) -> ReflectionQuestionType {
        let preferred = preferredType(for: link)
        // If metadata suggests a type different from last used, use it
        if preferred != lastQuestionType {
            lastQuestionType = preferred
            save()
            return preferred
        }
        // Otherwise rotate to the next in the list
        let all = ReflectionQuestionType.allCases
        let idx = all.firstIndex(of: lastQuestionType) ?? 0
        let next = all[(idx + 1) % all.count]
        lastQuestionType = next
        save()
        return next
    }

    private func preferredType(for link: Link) -> ReflectionQuestionType {
        let text = [(link.tags ?? ""), (link.category ?? "")].joined(separator: " ").lowercased()
        if text.contains("career") || text.contains("leadership") || text.contains("management") { return .connection }
        if text.contains("science") || text.contains("research") || text.contains("study")       { return .surprise }
        if text.contains("tech") || text.contains("engineering") || text.contains("code") || text.contains("product") { return .action }
        if text.contains("culture") || text.contains("opinion") || text.contains("politics")     { return .opinion }
        return .recall
    }

    // MARK: - Streak

    private func updateStreak() {
        let today = Calendar.current.startOfDay(for: Date())
        if let last = lastReflectionDate {
            let lastDay = Calendar.current.startOfDay(for: last)
            let days = Calendar.current.dateComponents([.day], from: lastDay, to: today).day ?? 0
            switch days {
            case 0:  break              // Same day — no change
            case 1:  currentStreak += 1 // Consecutive day
            default: currentStreak = 1  // Broke streak
            }
        } else {
            currentStreak = 1
        }
        lastReflectionDate = Date()
        save()
    }

    // MARK: - Depth score (0–100)

    func depthScore(for link: Link) -> Int {
        var score = 0
        if link.title != nil                                       { score += 10 }
        if let s = link.summary, !s.isEmpty                        { score += 15 }
        if (link.stars ?? 0) > 0                                   { score += 10 }
        if ArticleFullTextStore.shared.fetch(linkId: link.id) != nil { score += 20 }
        if let n = link.note, !n.isEmpty                           { score += 20 }
        if isReflected(link.id)                                    { score += 25 }
        return min(score, 100)
    }

    func depthColor(score: Int) -> Color {
        if score >= 70 { return .green }
        if score >= 40 { return .orange }
        return Color(.systemGray4)
    }

    // MARK: - Persistence

    private func load() {
        if let d = defaults.data(forKey: Keys.pending),
           let v = try? JSONDecoder().decode([String: Date].self, from: d) { pendingQueue = v }
        if let d = defaults.data(forKey: Keys.reflected),
           let v = try? JSONDecoder().decode(Set<String>.self, from: d) { reflectedIds = v }
        if let d = defaults.data(forKey: Keys.dismissed),
           let v = try? JSONDecoder().decode(Set<String>.self, from: d) { dismissedFromSuggestions = v }
        currentStreak = defaults.integer(forKey: Keys.streak)
        lastReflectionDate = defaults.object(forKey: Keys.lastDate) as? Date
        if let raw = defaults.string(forKey: Keys.lastType),
           let t = ReflectionQuestionType(rawValue: raw) { lastQuestionType = t }
    }

    private func save() {
        if let d = try? JSONEncoder().encode(pendingQueue)  { defaults.set(d, forKey: Keys.pending) }
        if let d = try? JSONEncoder().encode(reflectedIds)  { defaults.set(d, forKey: Keys.reflected) }
        if let d = try? JSONEncoder().encode(dismissedFromSuggestions) { defaults.set(d, forKey: Keys.dismissed) }
        defaults.set(currentStreak, forKey: Keys.streak)
        defaults.set(lastReflectionDate, forKey: Keys.lastDate)
        defaults.set(lastQuestionType.rawValue, forKey: Keys.lastType)
    }
}
