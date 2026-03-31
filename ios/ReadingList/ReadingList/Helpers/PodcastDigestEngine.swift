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

// MARK: - Generable structured output types (iOS 26 / FoundationModels)

#if canImport(FoundationModels)
@available(iOS 26, *)
@Generable
struct PodcastScript {
    @Guide(description: "Between 12 and 16 dialogue lines, alternating between KAI and DEV")
    var lines: [ScriptLine]
}

@available(iOS 26, *)
@Generable
struct ScriptLine {
    @Guide(description: "The speaker. Must be exactly KAI or DEV.")
    var speaker: String
    @Guide(description: "What they say. Casual, under 18 words. No stage directions.")
    var text: String
}
#endif

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
        // Hard cap: on-device model has a small context window (~4K tokens total)
        let trimmedContext = String(context.prefix(600))

        let instructions = """
        You are writing dialogue for a casual tech podcast called "The Backlog". \
        KAI explains ideas and makes connections ("Ok so here's the thing—", "No but think about it—"). \
        DEV reacts with enthusiasm and asks obvious questions ("Wait wait wait", "Oh dude", "Ok but WHY"). \
        Lines are short and punchy — under 18 words. Casual, like two friends on a couch. Dry humor welcome.
        """

        let prompt = """
        Write a 12-line podcast script where KAI and DEV discuss these saved articles. \
        Start with one line of off-topic banter. Have DEV misunderstand one article and KAI correct them. \
        End with KAI's top pick and DEV's disagreement.

        Articles:
        \(trimmedContext)
        """

        do {
            let session = LanguageModelSession(instructions: instructions)
            let result = try await session.respond(to: prompt, generating: PodcastScript.self)
            let lines: [PodcastLine] = result.content.lines.compactMap { line in
                switch line.speaker.uppercased().trimmingCharacters(in: .whitespaces) {
                case "KAI": return PodcastLine(speaker: .kai, text: line.text)
                case "DEV": return PodcastLine(speaker: .dev, text: line.text)
                default:    return nil
                }
            }
            guard !lines.isEmpty else {
                phase = .error("No dialogue generated — tap Regenerate to try again.")
                return
            }
            allLines = lines
            phase = .ready(lines)
        } catch {
            let desc = error.localizedDescription.lowercased()
            if desc.contains("available") || desc.contains("support") || desc.contains("intelligence") {
                phase = .unavailable("Apple Intelligence is not available on this device.")
            } else if desc.contains("context") || desc.contains("length") || desc.contains("token") {
                phase = .error("On-device AI context exceeded — tap Regenerate.")
            } else {
                phase = .error(error.localizedDescription)
            }
        }
        #else
        phase = .unavailable("FoundationModels framework is not available in this build.")
        #endif
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
