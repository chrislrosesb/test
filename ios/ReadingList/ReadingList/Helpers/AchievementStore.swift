import Foundation
import AudioToolbox

// MARK: - Models

struct Achievement: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let mood: ProcyMood
    let confettiLevel: ConfettiLevel
    let isRepeatable: Bool

    init(id: String, title: String, subtitle: String,
         mood: ProcyMood, confetti: ConfettiLevel = .none, repeatable: Bool = false) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.mood = mood
        self.confettiLevel = confetti
        self.isRepeatable = repeatable
    }
}

enum ProcyMood { case surprised, excited, chaos }
enum ConfettiLevel { case none, light, heavy }

// MARK: - Store

@Observable
@MainActor
final class AchievementStore {
    static let shared = AchievementStore()

    var current: Achievement? = nil

    private var queue: [Achievement] = []
    private var unlockedIds: Set<String>
    private(set) var currentStreak: Int = 0
    private var readDateStrings: [String]  // "yyyy-MM-dd"

    private init() {
        let ids = UserDefaults.standard.stringArray(forKey: "ach_unlocked") ?? []
        self.unlockedIds = Set(ids)
        self.readDateStrings = UserDefaults.standard.stringArray(forKey: "ach_readDates") ?? []
        self.currentStreak = Self.computeStreak(from: readDateStrings)
    }

    // MARK: - Public triggers

    // Called on each load — fires any save milestones not yet unlocked
    func articleSaved(totalSaved: Int) {
        let milestones = [1, 25, 100, 250]
        for m in milestones where totalSaved >= m {
            tryUnlock("save_\(m)")
        }
    }

    func articleRead(link: Link, totalRead: Int) {
        recordReadDate()

        // Read count milestones
        let milestones = [1, 10, 25, 50, 100]
        if milestones.contains(totalRead) { tryUnlock("read_\(totalRead)") }

        // Article Archaeologist: saved 30+ days ago
        if let savedDate = link.savedAt, Date().timeIntervalSince(savedDate) > 30 * 86400 {
            tryUnlock("archaeologist")
        }

        // Time-of-day
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 0 && hour < 4 { tryUnlock("night_owl") }
        if hour >= 5 && hour < 7 { tryUnlock("early_bird") }

        // Streak milestones
        checkStreakMilestones()
    }

    func noteSaved() {
        tryUnlock("note_first")
    }

    func deepSaved() {
        tryUnlock("deep_first")
    }

    func fiveStarRated() {
        tryUnlock("five_star")
    }

    func toReadCleared() {
        tryUnlock("clear_toread")
    }

    func dismiss() {
        current = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.showNext()
        }
    }

    // MARK: - Private

    private func tryUnlock(_ id: String) {
        guard !isUnlocked(id),
              let a = Self.catalog.first(where: { $0.id == id }) else { return }
        if !a.isRepeatable { markUnlocked(id) }
        enqueue(a)
    }

    private func checkStreakMilestones() {
        let streak = currentStreak
        let milestones = [7, 14, 21, 28, 30, 60, 90, 180, 365]
        for m in milestones where streak == m {
            enqueue(streakAchievement(days: m))
        }
    }

    private func recordReadDate() {
        let today = dateKey(for: Date())
        if !readDateStrings.contains(today) {
            readDateStrings.append(today)
            UserDefaults.standard.set(readDateStrings, forKey: "ach_readDates")
        }
        currentStreak = Self.computeStreak(from: readDateStrings)
    }

    private func isUnlocked(_ id: String) -> Bool { unlockedIds.contains(id) }

    private func markUnlocked(_ id: String) {
        unlockedIds.insert(id)
        UserDefaults.standard.set(Array(unlockedIds), forKey: "ach_unlocked")
    }

    private func enqueue(_ a: Achievement) {
        queue.append(a)
        if current == nil { showNext() }
    }

    private func showNext() {
        guard !queue.isEmpty else { return }
        current = queue.removeFirst()
        playSound(for: current!.confettiLevel)
    }

    private func playSound(for level: ConfettiLevel) {
        switch level {
        case .heavy: AudioServicesPlaySystemSound(1322)  // success chime
        case .light: AudioServicesPlaySystemSound(1057)  // soft ding
        case .none:  AudioServicesPlaySystemSound(1057)
        }
    }

    private func dateKey(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }

    static func computeStreak(from dateStrings: [String]) -> Int {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let dates = Set(dateStrings.compactMap { fmt.date(from: $0) }
            .map { Calendar.current.startOfDay(for: $0) })
        guard !dates.isEmpty else { return 0 }

        var check = Calendar.current.startOfDay(for: Date())
        // Anchor on today or yesterday
        if !dates.contains(check) {
            guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: check) else { return 0 }
            check = prev
            if !dates.contains(check) { return 0 }
        }

        var streak = 0
        while dates.contains(check) {
            streak += 1
            guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: check) else { break }
            check = prev
        }
        return streak
    }

    // MARK: - Dynamic streak achievements (repeatable, copy varies by day count)

    private func streakAchievement(days: Int) -> Achievement {
        typealias C = (title: String, sub: String, mood: ProcyMood, confetti: ConfettiLevel)
        let table: [Int: C] = [
            7:   ("On A Roll",           "7 days straight. The old you would never.",                          .excited, .light),
            14:  ("Two Weeks Strong",    "14 days. You have a problem. A good one.",                          .excited, .heavy),
            21:  ("Habit Formation",     "21 days. Science says this is permanent now. No backsies.",         .excited, .heavy),
            28:  ("Month-Adjacent",      "28 days. You've almost fully betrayed the brand.",                  .chaos,   .heavy),
            30:  ("One Month",           "30-day streak. Procy filed identity crisis paperwork.",             .chaos,   .heavy),
            60:  ("Two Months",          "60 days. Procy needs a moment to process this.",                   .chaos,   .heavy),
            90:  ("The Long Game",       "90 days. Genuinely worried about you.",                            .chaos,   .heavy),
            180: ("Half A Year",         "180 days. You might just be a reader now.",                        .chaos,   .heavy),
            365: ("Former Procrastinator","365 days. The procrastinator is gone. You're just a reader.",     .chaos,   .heavy),
        ]
        let c = table[days] ?? C("Day \(days) Streak", "Keep going.", .excited, .light)
        return Achievement(
            id: "streak_\(days)",
            title: c.title,
            subtitle: "🔥 \(days)-day streak — \(c.sub)",
            mood: c.mood,
            confetti: c.confetti,
            repeatable: true
        )
    }

    // MARK: - Static catalog (one-time unlocks)

    static let catalog: [Achievement] = [
        // Saving milestones
        Achievement(id: "save_1",   title: "Future You Will Handle It", subtitle: "Your first saved article. It's definitely getting read someday.",  mood: .surprised, confetti: .none),
        Achievement(id: "save_25",  title: "Tab Hoarder",               subtitle: "25 articles saved. You're basically a digital packrat.",           mood: .excited,   confetti: .light),
        Achievement(id: "save_100", title: "The Collection",            subtitle: "100 articles. A monument to good intentions.",                     mood: .chaos,     confetti: .heavy),
        Achievement(id: "save_250", title: "Committed to the Bit",      subtitle: "250 saved. At this point it's a lifestyle.",                       mood: .chaos,     confetti: .heavy),

        // Reading milestones
        Achievement(id: "read_1",   title: "Okay, Maybe Now",           subtitle: "You actually read something. We're all shocked.",                  mood: .surprised, confetti: .light),
        Achievement(id: "read_10",  title: "Reformed Procrastinator",   subtitle: "10 articles read. The procrastination is on the run.",             mood: .excited,   confetti: .heavy),
        Achievement(id: "read_25",  title: "Voracious (Allegedly)",     subtitle: "25 done. Your past self is deeply confused.",                      mood: .chaos,     confetti: .heavy),
        Achievement(id: "read_50",  title: "Who Even Are You",          subtitle: "50 articles read. You've fully betrayed the brand.",               mood: .chaos,     confetti: .heavy),
        Achievement(id: "read_100", title: "Former Procrastinator",     subtitle: "100 reads. Procy is filing for identity crisis paperwork.",        mood: .chaos,     confetti: .heavy),

        // Special
        Achievement(id: "archaeologist", title: "Article Archaeologist", subtitle: "Finished something saved 30+ days ago. Legendary patience.",     mood: .excited,   confetti: .heavy),
        Achievement(id: "deep_first",    title: "Deep Diver",            subtitle: "First full-text save. You're actually committed to this one.",    mood: .surprised, confetti: .none),
        Achievement(id: "note_first",    title: "Big Thoughts",          subtitle: "Your first note. We'll assume it's profound.",                    mood: .surprised, confetti: .none),
        Achievement(id: "five_star",     title: "This Slaps",            subtitle: "5 stars. Genuinely moved by an article, apparently.",             mood: .excited,   confetti: .light),
        Achievement(id: "night_owl",     title: "Midnight Reader",       subtitle: "Reading after midnight. Passionate or panicked — we don't judge.",mood: .chaos,     confetti: .none),
        Achievement(id: "early_bird",    title: "Morning Person (??)",   subtitle: "Before 7am. Please seek help.",                                   mood: .excited,   confetti: .none),
        Achievement(id: "clear_toread",  title: "Inbox Zero (Articles)", subtitle: "Cleared your to-read list. Procy is beside himself.",             mood: .chaos,     confetti: .heavy),
    ]
}
