import Foundation
import AVFoundation
import SwiftUI

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
    case generatingScript
    case synthesizingAudio
    case ready([PodcastLine])
    case playing(currentLine: Int)
    case paused(currentLine: Int)
    case error(String)
    case missingAPIKey
}

// MARK: - Engine

@MainActor
@Observable
final class PodcastDigestEngine: NSObject {

    var phase: PodcastPhase = .idle
    private(set) var playbackIndex: Int = 0
    var allLines: [PodcastLine] = []

    private var audioPlayer: AVAudioPlayer?
    private var playbackTimer: Timer?
    private var lineStartTimes: [TimeInterval] = []
    private var audioFileURL: URL?

    private let scriptModel = "gemini-2.5-flash"
    private let ttsModel = "gemini-2.5-flash-preview-tts"
    private let geminiBase = "https://generativelanguage.googleapis.com/v1beta/models"

    private var apiKey: String {
        UserDefaults.standard.string(forKey: "geminiAPIKey") ?? ""
    }

    // MARK: - Generate

    func generate(context: String) async {
        guard !apiKey.isEmpty else {
            phase = .missingAPIKey
            return
        }
        guard !context.isEmpty else {
            phase = .error("No articles found. Save some links first.")
            return
        }

        do {
            phase = .generatingScript
            let lines = try await generateScript(context: context)
            guard !lines.isEmpty else {
                phase = .error("Couldn't parse a script from the response — tap Regenerate.")
                return
            }
            allLines = lines

            phase = .synthesizingAudio
            let url = try await synthesizeAudio(lines: lines)
            audioFileURL = url
            phase = .ready(lines)
        } catch {
            phase = .error((error as? GeminiError)?.message ?? error.localizedDescription)
        }
    }

    func regenerate(context: String) {
        audioPlayer?.stop()
        stopTimer()
        if let url = audioFileURL { try? FileManager.default.removeItem(at: url) }
        audioFileURL = nil
        allLines = []
        playbackIndex = 0
        phase = .idle
        Task { await generate(context: context) }
    }

    // MARK: - Script Generation (Gemini 2.5 Flash)

    private func generateScript(context: String) async throws -> [PodcastLine] {
        let url = URL(string: "\(geminiBase)/\(scriptModel):generateContent?key=\(apiKey)")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 60

        let prompt = buildScriptPrompt(context: context)
        let body: [String: Any] = [
            "contents": [["role": "user", "parts": [["text": prompt]]]],
            "generationConfig": ["temperature": 0.9, "maxOutputTokens": 8192]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        try checkGeminiStatus(response, data: data)
        let text = try extractGeminiText(data)
        return parseScript(text)
    }

    private func buildScriptPrompt(context: String) -> String {
        """
        You write scripts for "The Backlog" — a casual, entertaining tech/internet podcast in the style of Diggnation and Relay FM's Connected.

        KAI is the explainer: makes connections between topics, leads the analysis, occasionally goes deep on something obscure. Phrases: "Ok so here's the thing—", "No but think about it—", "This is actually wild because..."
        DEV is the reactor: skeptical at first, then sometimes more excited than KAI. Asks the obvious question that everyone's thinking. Deflates takes before buying in. Phrases: "Wait wait wait", "Ok but WHY though", "...actually ok fair", "No I hear you but—"

        RULES — follow these exactly:
        1. Open with ONE casual banter line that is not "welcome to the show" and not about the articles
        2. Cover exactly 3 articles as main topics. VARIETY IS REQUIRED: scan the ENTIRE list before choosing — do not default to the first articles you see. Each regeneration should explore different corners of the library. Prioritise: (a) articles with a "My note:" entry — these signal genuine personal investment, (b) articles with a Digest — rich content to discuss, (c) high star ratings. Spread topics across different domains/themes where possible.
        3. OPINIONS FIRST: state the take before the context. Assume the listener already read the headline.
        4. One host must be noticeably more into each story than the other — asymmetric enthusiasm drives the banter
        5. Use the "yeah but" structure: every strong take gets a line of pushback or added texture from the other host
        6. NEVER resolve disagreements cleanly. End segments with "we'll see", "I still think...", or partial concession only
        7. Transitions must be organic — connect the tail of one topic to the next. Never say "moving on to our next story"
        8. When an article has a "My note:" entry, work that personal perspective directly into the dialogue — it should feel like KAI or DEV's own thought, not a quote
        9. Lines should be 10-25 words. Punchy. Real speech rhythm, not writing.
        10. Total: 26-32 lines for a 7-9 minute episode
        11. Format: every line starts with exactly "KAI: " or "DEV: " — no other formatting, no stage directions, no blank lines

        User's saved articles:

        \(context)

        Write the script:
        """
    }

    private func parseScript(_ text: String) -> [PodcastLine] {
        text.components(separatedBy: "\n").compactMap { line in
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("KAI:") {
                let body = t.dropFirst(4).trimmingCharacters(in: .whitespaces)
                return body.isEmpty ? nil : PodcastLine(speaker: .kai, text: body)
            } else if t.hasPrefix("DEV:") {
                let body = t.dropFirst(4).trimmingCharacters(in: .whitespaces)
                return body.isEmpty ? nil : PodcastLine(speaker: .dev, text: body)
            }
            return nil
        }
    }

    // MARK: - Audio Synthesis (Gemini 2.5 Flash TTS)

    private func synthesizeAudio(lines: [PodcastLine]) async throws -> URL {
        let scriptText = lines.map { "\($0.speaker.rawValue): \($0.text)" }.joined(separator: "\n")

        let url = URL(string: "\(geminiBase)/\(ttsModel):generateContent?key=\(apiKey)")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 180 // TTS for a full episode can take time

        let body: [String: Any] = [
            "contents": [["parts": [["text": scriptText]]]],
            "generationConfig": [
                "responseModalities": ["AUDIO"],
                "speechConfig": [
                    "multiSpeakerVoiceConfig": [
                        "speakerVoiceConfigs": [
                            ["speaker": "KAI", "voiceConfig": ["prebuiltVoiceConfig": ["voiceName": "Charon"]]],
                            ["speaker": "DEV", "voiceConfig": ["prebuiltVoiceConfig": ["voiceName": "Fenrir"]]]
                        ]
                    ]
                ]
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        try checkGeminiStatus(response, data: data)
        let pcmData = try extractAudioData(data)
        let wavData = makeWAV(pcmData: pcmData)

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("backlog_\(Int(Date().timeIntervalSince1970)).wav")
        try wavData.write(to: fileURL)
        return fileURL
    }

    /// Wraps raw 16-bit 24kHz mono PCM in a WAV container.
    private func makeWAV(pcmData: Data) -> Data {
        let sampleRate: UInt32 = 24000
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample) / 8
        let blockAlign = channels * bitsPerSample / 8
        let dataSize = UInt32(pcmData.count)

        var h = Data()
        h += "RIFF".utf8;  h.appendLE(36 + dataSize)
        h += "WAVE".utf8
        h += "fmt ".utf8;  h.appendLE(UInt32(16))
        h.appendLE(UInt16(1))      // PCM
        h.appendLE(channels)
        h.appendLE(sampleRate)
        h.appendLE(byteRate)
        h.appendLE(blockAlign)
        h.appendLE(bitsPerSample)
        h += "data".utf8;  h.appendLE(dataSize)
        return h + pcmData
    }

    // MARK: - Gemini Helpers

    private func checkGeminiStatus(_ response: URLResponse, data: Data) throws {
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(status) else {
            struct ErrResp: Decodable { struct E: Decodable { let message: String }; let error: E }
            let msg = (try? JSONDecoder().decode(ErrResp.self, from: data))?.error.message
            switch status {
            case 401, 403: throw GeminiError("Invalid API key — update it in Profile > AI Services.")
            case 429:      throw GeminiError("Rate limit reached — wait a moment and try again.")
            default:       throw GeminiError(msg ?? "Gemini request failed (HTTP \(status)).")
            }
        }
    }

    private func extractGeminiText(_ data: Data) throws -> String {
        struct Resp: Decodable {
            struct Candidate: Decodable {
                struct Content: Decodable {
                    struct Part: Decodable { let text: String? }
                    let parts: [Part]
                }
                let content: Content
            }
            let candidates: [Candidate]
        }
        guard let text = (try JSONDecoder().decode(Resp.self, from: data))
                .candidates.first?.content.parts.first?.text else {
            throw GeminiError("Empty script response from Gemini.")
        }
        return text
    }

    private func extractAudioData(_ data: Data) throws -> Data {
        struct Resp: Decodable {
            struct Candidate: Decodable {
                struct Content: Decodable {
                    struct Part: Decodable {
                        struct InlineData: Decodable { let data: String }
                        let inlineData: InlineData?
                    }
                    let parts: [Part]
                }
                let content: Content
            }
            let candidates: [Candidate]
        }
        guard let b64 = (try JSONDecoder().decode(Resp.self, from: data))
                .candidates.first?.content.parts.first?.inlineData?.data,
              let pcm = Data(base64Encoded: b64) else {
            throw GeminiError("No audio data in TTS response.")
        }
        return pcm
    }

    // MARK: - Playback

    func play() {
        guard let url = audioFileURL else { return }
        configureAudioSession()
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            computeLineTimings()
            playbackIndex = 0
            phase = .playing(currentLine: 0)
            startTimer()
        } catch {
            phase = .error("Could not play audio: \(error.localizedDescription)")
        }
    }

    func pause() {
        guard case .playing(let idx) = phase else { return }
        audioPlayer?.pause()
        stopTimer()
        phase = .paused(currentLine: idx)
    }

    func resume() {
        guard case .paused(let idx) = phase else { return }
        audioPlayer?.play()
        phase = .playing(currentLine: idx)
        startTimer()
    }

    func stop() {
        audioPlayer?.stop()
        stopTimer()
        playbackIndex = 0
        phase = .ready(allLines)
    }

    func restart() {
        stop()
        play()
    }

    // MARK: - Line Timing (character-proportional estimation)

    private func computeLineTimings() {
        guard let duration = audioPlayer?.duration, duration > 0 else {
            lineStartTimes = Array(repeating: 0, count: allLines.count)
            return
        }
        let totalChars = max(1, allLines.reduce(0) { $0 + $1.text.count })
        var cumulative = 0
        lineStartTimes = allLines.map { line in
            let t = Double(cumulative) / Double(totalChars) * duration
            cumulative += line.text.count
            return t
        }
    }

    private func startTimer() {
        stopTimer()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tickPlayback() }
        }
    }

    private func stopTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func tickPlayback() {
        guard let player = audioPlayer, player.isPlaying, !lineStartTimes.isEmpty else { return }
        let idx = lineStartTimes.lastIndex(where: { $0 <= player.currentTime }) ?? 0
        guard idx != playbackIndex else { return }
        playbackIndex = idx
        phase = .playing(currentLine: idx)
    }

    var currentProgress: Double {
        guard let p = audioPlayer, p.duration > 0 else { return 0 }
        return p.currentTime / p.duration
    }

    var audioCurrentTime: TimeInterval  { audioPlayer?.currentTime ?? 0 }
    var audioDuration: TimeInterval     { audioPlayer?.duration ?? 0 }

    private func configureAudioSession() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
    }
}

// MARK: - AVAudioPlayerDelegate

extension PodcastDigestEngine: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.stopTimer()
            self.playbackIndex = 0
            self.phase = .ready(self.allLines)
        }
    }
}

// MARK: - Error

struct GeminiError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

// MARK: - Data + little-endian helper

private extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }
}

// MARK: - SwiftUI Color (needed by PodcastSpeaker)
import SwiftUI
