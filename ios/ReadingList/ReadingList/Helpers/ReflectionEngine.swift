import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Types

struct ReflectionMessage: Identifiable {
    let id = UUID()
    let role: ReflectionRole
    let text: String
}

enum ReflectionRole { case ai, user }

enum ReflectionPhase: Equatable {
    case idle
    case thinking
    case waitingForAnswer(exchange: Int) // 1 = first, 2 = follow-up
    case saving
    case done(savedNote: String)
    case error(String)
    case unavailable(String)
}

// MARK: - Engine

@MainActor
@Observable
final class ReflectionEngine {
    var messages: [ReflectionMessage] = []
    var phase: ReflectionPhase = .idle
    var inputText: String = ""

    private let link: Link
    private var questionType: ReflectionQuestionType = .recall
    private var firstAnswer: String = ""

    init(link: Link) {
        self.link = link
        // Do NOT call nextQuestionType here — it writes to UserDefaults and mutates
        // @Observable state, which deadlocks if called during SwiftUI view init.
    }

    // MARK: - Start

    func start() async {
        // Determine question type here (safe: called from async context, not init)
        questionType = ReflectionStore.shared.nextQuestionType(for: link)
        phase = .thinking
        if #available(iOS 26, *) {
            await generateOpeningQuestion()
        } else {
            phase = .unavailable("Reflect requires iOS 26 and Apple Intelligence.")
        }
    }

    // MARK: - Submit answer

    func submitAnswer() async {
        guard case .waitingForAnswer(let exchange) = phase else { return }
        let answer = inputText.trimmingCharacters(in: .whitespaces)
        guard !answer.isEmpty else { return }

        messages.append(ReflectionMessage(role: .user, text: answer))
        inputText = ""

        if exchange == 1 {
            firstAnswer = answer
            phase = .thinking
            if #available(iOS 26, *) {
                await generateFollowUp(to: answer)
            }
        } else {
            // Second exchange complete — build and return note
            let note = buildNote(firstAnswer: firstAnswer, secondAnswer: answer)
            phase = .done(savedNote: note)
        }
    }

    // MARK: - Generation

    @available(iOS 26, *)
    private func generateOpeningQuestion() async {
        #if canImport(FoundationModels)
        let instructions = """
        You are a thoughtful reading companion helping someone reflect on articles they've read. \
        Ask one sharp, specific question grounded in THIS article's actual content and the user's situation. \
        Never ask generic questions like "what did you think?" — make it specific. \
        One sentence only. Be curious, not academic. No preamble.
        """

        let existingNote = (link.note ?? "").trimmingCharacters(in: .whitespaces)
        let noteContext = existingNote.isEmpty
            ? "They haven't written any notes yet."
            : "They already noted: \"\(String(existingNote.prefix(200)))\" — build on this, don't repeat it."

        let prompt = """
        Article: \(articleContext)

        \(noteContext)

        \(questionGuide)
        """

        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt)
            let question = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            messages.append(ReflectionMessage(role: .ai, text: question))
            phase = .waitingForAnswer(exchange: 1)
        } catch {
            phase = .error(error.localizedDescription)
        }
        #endif
    }

    @available(iOS 26, *)
    private func generateFollowUp(to answer: String) async {
        #if canImport(FoundationModels)
        let instructions = """
        You are a thoughtful reading companion. The user just answered a question about an article. \
        Acknowledge their answer in one short sentence, then ask one specific follow-up that digs deeper \
        into what they said. Total response under 30 words. Conversational, not academic.
        """

        let openingQ = messages.first(where: { $0.role == .ai })?.text ?? ""
        let prompt = """
        Article: \(articleContext)

        You asked: \(openingQ)
        They answered: \(answer)

        Write your brief acknowledgement + one follow-up question.
        """

        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt)
            let followUp = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            messages.append(ReflectionMessage(role: .ai, text: followUp))
            phase = .waitingForAnswer(exchange: 2)
        } catch {
            // Follow-up failed — finish gracefully with what we have
            let note = buildNote(firstAnswer: firstAnswer, secondAnswer: "")
            phase = .done(savedNote: note)
        }
        #endif
    }

    // MARK: - Note building

    private func buildNote(firstAnswer: String, secondAnswer: String) -> String {
        var parts: [String] = []

        // Preserve existing note
        let existing = (link.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !existing.isEmpty {
            parts.append(existing)
            parts.append("---")
        }

        let q1 = messages.first(where: { $0.role == .ai })?.text ?? ""
        if !q1.isEmpty && !firstAnswer.isEmpty {
            parts.append("Q: \(q1)\nA: \(firstAnswer)")
        }

        let q2 = messages.filter({ $0.role == .ai }).dropFirst().first?.text ?? ""
        if !secondAnswer.isEmpty {
            parts.append(q2.isEmpty ? secondAnswer : "Q: \(q2)\nA: \(secondAnswer)")
        }

        return parts.joined(separator: "\n\n")
    }

    // MARK: - Helpers

    private var articleContext: String {
        var parts: [String] = []
        parts.append("\"\(link.title ?? link.url)\" (\(link.domain ?? "unknown"))")
        if let tags = link.tags,     !tags.isEmpty   { parts.append("Tags: \(tags)") }
        if let cat  = link.category, !cat.isEmpty    { parts.append("Category: \(cat)") }
        if let stars = link.stars,    stars > 0      { parts.append("Rated \(stars)/5 stars") }
        if let ft = ArticleFullTextStore.shared.fetch(linkId: link.id), !ft.digest.isEmpty {
            parts.append("Summary: \(String(ft.digest.prefix(350)))")
        } else if let s = link.summary, !s.isEmpty {
            parts.append("Summary: \(String(s.prefix(250)))")
        }
        return parts.joined(separator: "\n")
    }

    private var questionGuide: String {
        switch questionType {
        case .action:
            return "Ask what specific thing they'd actually try, build, or change based on this article."
        case .connection:
            return "Ask how this connects to something real in their current work or life right now."
        case .surprise:
            return "Ask what here contradicted their expectations or shifted how they think about something."
        case .opinion:
            return "Ask whether they agree with the author's main argument — and specifically where they'd push back."
        case .recall:
            return "Ask what single insight from this they'd most want to remember in a year."
        }
    }
}
