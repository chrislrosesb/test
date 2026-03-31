import Foundation
import AVFoundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Data types

struct PodcastLine: Identifiable {
    let id = UUID()
    let speaker: PodcastSpeaker
    let text: String
}

enum PodcastSpeaker: String, CaseIterable {
    case kai = "KAI"
    case dev = "DEV"

    var displayName: String { "  \(rawValue.prefix(1))\(rawValue.dropFirst().lowercased())  " }
    var color: Color {
        switch self {
        case .kai: return .indigo
        case .dev: return .orange
        }
    }
    var emoji: String {
        switch self {
        case .kai: return "🧠"
        case .dev: return "⚡️"
        }
    }
}

enum PodcastPhase {
    case idle
    case generating
    case ready([PodcastLine])
    case playing(currentLine: Int)
    case paused(currentLine: Int)
    case error(String)
    case unavailable(String)

}

// MARK: - Engine

@MainActor
@Observable
final class PodcastDigestEngine: NSObject {

    var phase: PodcastPhase = .idle

    // Playback state
    private(set) var playbackIndex: Int = 0
    var allLines: [PodcastLine] = []
    private var isStopRequested = false
    private var cachedVoices: (kai: AVSpeechSynthesisVoice, dev: AVSpeechSynthesisVoice)?

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Voice selection

    private func pickVoices() -> (kai: AVSpeechSynthesisVoice, dev: AVSpeechSynthesisVoice) {
        if let cached = cachedVoices { return cached }

        let all = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en-") }

        func quality(_ v: AVSpeechSynthesisVoice) -> Int {
            let id = v.identifier.lowercased()
            if id.contains("premium") { return 3 }
            if id.contains("enhanced") { return 2 }
            return 1
        }

        let sorted = all.sorted { quality($0) > quality($1) }
        let first  = sorted.first ?? AVSpeechSynthesisVoice(language: "en-US")!
        // Pick a second voice that's different — prefer a different name in the identifier
        let second = sorted.first(where: {
            $0.identifier != first.identifier &&
            $0.language == first.language
        }) ?? sorted.first(where: { $0.identifier != first.identifier })
               ?? AVSpeechSynthesisVoice(language: "en-AU") ?? first

        let result = (kai: first, dev: second)
        cachedVoices = result
        return result
    }

    // MARK: - Script Generation

    func generate(context: String) async {
        guard !context.isEmpty else {
            phase = .unavailable("No articles found. Save some links first.")
            return
        }
        phase = .generating
        if #available(iOS 26, *) {
            await generateScript(context: context)
        } else {
            phase = .unavailable("Audio Briefing requires iOS 26 and Apple Intelligence.")
        }
    }

    @available(iOS 26, *)
    private func generateScript(context: String) async {
        #if canImport(FoundationModels)
        let prompt = """
        You are writing a script for "The Backlog" — a casual, irreverent two-host podcast in the style of Diggnation (Kevin Rose and Alex Albrecht). Two friends who genuinely love this stuff but don't take themselves seriously.

        The hosts:
        KAI — the knowledgeable one. Explains things, makes connections, occasionally nerds out. Phrases: "Ok so here's the thing—", "What I find interesting is", "This actually connects to", "No but think about it—"

        DEV — the enthusiast. Reacts big, asks obvious questions, brings energy, goes on tangents. Phrases: "Wait wait wait", "Oh dude", "No that's actually wild", "Ok but WHY though", "Hang on—"

        Vibe: Two friends podcasting from a couch. They interrupt each other using em-dash (—). They agree and then build. Occasional dry humor. No corporate speak. Short punchy lines — under 25 words each.

        Here are the articles from the reading list this week:

        \(context)

        SCRIPT RULES:
        - Format every line as exactly: [KAI] text OR [DEV] text — nothing else, no blank lines between exchanges
        - 18–24 exchanges total
        - Open with one line of light banter completely unrelated to the articles (inside joke feel)
        - Cover the 3 most interesting articles with real back-and-forth on each
        - ONE moment where DEV completely misunderstands an article concept and KAI corrects them with mock exasperation
        - End: KAI gives a "if you read ONE thing this week" pick, DEV disagrees with a hot take
        - No asterisks, no parentheticals, no stage directions, no markdown — dialogue text only
        """

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            let parsed = parseScript(response.content)
            guard !parsed.isEmpty else {
                phase = .error("Script came back empty — try regenerating.")
                return
            }
            allLines = parsed
            phase = .ready(parsed)
        } catch {
            let desc = error.localizedDescription.lowercased()
            if desc.contains("available") || desc.contains("support") || desc.contains("intelligence") {
                phase = .unavailable("Apple Intelligence is not available on this device.")
            } else {
                phase = .error(error.localizedDescription)
            }
        }
        #else
        phase = .unavailable("FoundationModels framework is not available in this build.")
        #endif
    }

    private func parseScript(_ raw: String) -> [PodcastLine] {
        raw.components(separatedBy: .newlines).compactMap { line in
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.uppercased().hasPrefix("[KAI]") {
                let text = t.dropFirst(5).trimmingCharacters(in: .whitespaces)
                return text.isEmpty ? nil : PodcastLine(speaker: .kai, text: text)
            } else if t.uppercased().hasPrefix("[DEV]") {
                let text = t.dropFirst(5).trimmingCharacters(in: .whitespaces)
                return text.isEmpty ? nil : PodcastLine(speaker: .dev, text: text)
            }
            // Also accept "KAI: " or "DEV: " format as fallback
            if t.uppercased().hasPrefix("KAI:") {
                let text = t.dropFirst(4).trimmingCharacters(in: .whitespaces)
                return text.isEmpty ? nil : PodcastLine(speaker: .kai, text: text)
            } else if t.uppercased().hasPrefix("DEV:") {
                let text = t.dropFirst(4).trimmingCharacters(in: .whitespaces)
                return text.isEmpty ? nil : PodcastLine(speaker: .dev, text: text)
            }
            return nil
        }
    }

    // MARK: - Playback Control

    func play() {
        guard case .ready(let lines) = phase else { return }
        allLines = lines
        startPlayback(from: 0)
    }

    func resume() {
        guard case .paused(let idx) = phase else { return }
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
            phase = .playing(currentLine: idx)
        } else {
            startPlayback(from: idx)
        }
    }

    func pause() {
        guard case .playing(let idx) = phase else { return }
        synthesizer.pauseSpeaking(at: .word)
        phase = .paused(currentLine: idx)
    }

    func stop() {
        isStopRequested = true
        synthesizer.stopSpeaking(at: .immediate)
        phase = .ready(allLines)
    }

    func restart() {
        stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.play()
        }
    }

    func regenerate(context: String) {
        stop()
        allLines = []
        phase = .idle
        Task { await generate(context: context) }
    }

    private func startPlayback(from index: Int) {
        isStopRequested = false
        playbackIndex = index
        configureAudioSession()
        speakLine(at: index)
    }

    private func speakLine(at index: Int) {
        guard index < allLines.count, !isStopRequested else {
            if !isStopRequested { phase = .ready(allLines) }
            return
        }

        let line = allLines[index]
        let voices = pickVoices()

        let utterance = AVSpeechUtterance(string: line.text)

        switch line.speaker {
        case .kai:
            utterance.voice = voices.kai
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
            utterance.pitchMultiplier = 1.08
            utterance.volume = 0.95
        case .dev:
            utterance.voice = voices.dev
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.97
            utterance.pitchMultiplier = 0.90
            utterance.volume = 1.0
        }

        utterance.preUtteranceDelay  = index == 0 ? 0.1 : 0.28
        utterance.postUtteranceDelay = 0.05

        phase = .playing(currentLine: index)
        synthesizer.speak(utterance)
    }

    private func configureAudioSession() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(
            .playback,
            mode: .spokenAudio,
            options: [.duckOthers]
        )
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension PodcastDigestEngine: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self, !self.isStopRequested else { return }
            let next = self.playbackIndex + 1
            self.playbackIndex = next
            self.speakLine(at: next)
        }
    }
}

// MARK: - SwiftUI Color (needed by PodcastSpeaker)
import SwiftUI
