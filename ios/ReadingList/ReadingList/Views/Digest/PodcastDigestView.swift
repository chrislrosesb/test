import SwiftUI
import AVFoundation

// MARK: - Podcast Digest View

struct PodcastDigestView: View {
    @Environment(LibraryViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    @State private var engine = PodcastDigestEngine()

    // Computed context: last 7 days first, fallback to most recent 10 articles
    private var podcastContext: String { vm.podcastContext }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                showHeader
                Divider()
                contentArea
                Divider()
                playbackBar
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if case .ready = engine.phase {
                        Button {
                            engine.regenerate(context: podcastContext)
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
        }
        .onDisappear { engine.stop() }
    }

    // MARK: - Show Header

    var showHeader: some View {
        HStack(alignment: .center, spacing: 20) {
            // Show identity
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "waveform.and.mic")
                        .font(.headline)
                        .foregroundStyle(.purple)
                    Text("The Backlog")
                        .font(.headline)
                        .fontWeight(.black)
                }
                Text("Your weekly audio briefing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Host chips
            HStack(spacing: 10) {
                hostChip(.kai, isActive: activeHost == .kai)
                hostChip(.dev, isActive: activeHost == .dev)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // Currently speaking host (nil if not playing)
    var activeHost: PodcastSpeaker? {
        switch engine.phase {
        case .playing(let idx), .paused(let idx):
            return engine.allLines[safe: idx]?.speaker
        default:
            return nil
        }
    }

    @ViewBuilder
    func hostChip(_ speaker: PodcastSpeaker, isActive: Bool) -> some View {
        HStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(isActive ? speaker.color : speaker.color.opacity(0.15))
                    .frame(width: 28, height: 28)
                Text(speaker.emoji)
                    .font(.system(size: 14))
            }
            Text(speaker.rawValue.prefix(1).uppercased() + speaker.rawValue.dropFirst().lowercased())
                .font(.caption)
                .fontWeight(isActive ? .bold : .regular)
                .foregroundStyle(isActive ? speaker.color : .secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(isActive ? speaker.color.opacity(0.12) : Color(.tertiarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(isActive ? speaker.color.opacity(0.4) : Color.clear, lineWidth: 1)
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }

    // MARK: - Content Area

    @ViewBuilder
    var contentArea: some View {
        switch engine.phase {
        case .idle:
            idleView

        case .generatingScript:
            generatingView(title: "Writing the episode…", subtitle: "Kai and Dev are prepping their takes.")

        case .synthesizingAudio:
            generatingView(title: "Rendering audio…", subtitle: "Gemini is recording the episode. This takes ~30 seconds.")

        case .ready, .playing, .paused:
            scriptView(lines: engine.allLines)

        case .missingAPIKey:
            missingAPIKeyView

        case .error(let msg):
            errorView(msg)
        }
    }

    var idleView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "waveform.and.mic")
                .font(.system(size: 52))
                .foregroundStyle(.purple.opacity(0.6))
            VStack(spacing: 8) {
                Text("Ready to roll")
                    .font(.title3)
                    .fontWeight(.bold)
                Text("Kai and Dev will discuss your recent saves.\nPowered by Gemini — takes about 30 seconds.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                Task { await engine.generate(context: podcastContext) }
            } label: {
                Label("Generate Episode", systemImage: "sparkles")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .padding(.horizontal, 40)
            Spacer()
        }
        .padding()
    }

    func generatingView(title: String, subtitle: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.4)
            VStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
        }
    }

    var missingAPIKeyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "key.slash")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Gemini API key required")
                .font(.headline)
            Text("Add your free key in Profile > AI Services.\nGet one at aistudio.google.com — no credit card needed.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    func scriptView(lines: [PodcastLine]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(lines.enumerated()), id: \.element.id) { idx, line in
                        scriptBubble(line: line, index: idx)
                            .id(line.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: engine.playbackIndex) { _, newIdx in
                if let line = lines[safe: newIdx] {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(line.id, anchor: .center)
                    }
                }
            }
        }
    }

    @ViewBuilder
    func scriptBubble(line: PodcastLine, index: Int) -> some View {
        let isCurrentLine: Bool = {
            switch engine.phase {
            case .playing(let idx), .paused(let idx): return idx == index
            default: return false
            }
        }()
        let isPast: Bool = {
            switch engine.phase {
            case .playing(let idx), .paused(let idx): return index < idx
            default: return false
            }
        }()

        HStack(alignment: .top, spacing: 10) {
            if line.speaker == .kai {
                speakerDot(line.speaker, isActive: isCurrentLine)
                bubbleContent(line: line, isCurrentLine: isCurrentLine, isPast: isPast, alignRight: false)
                Spacer(minLength: 48)
            } else {
                Spacer(minLength: 48)
                bubbleContent(line: line, isCurrentLine: isCurrentLine, isPast: isPast, alignRight: true)
                speakerDot(line.speaker, isActive: isCurrentLine)
            }
        }
        .padding(.vertical, 3)
        .animation(.easeInOut(duration: 0.2), value: isCurrentLine)
    }

    func speakerDot(_ speaker: PodcastSpeaker, isActive: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isActive ? speaker.color : speaker.color.opacity(0.2))
                .frame(width: 22, height: 22)
            Text(speaker.emoji)
                .font(.system(size: 10))
        }
        .padding(.top, 8)
    }

    func bubbleContent(line: PodcastLine, isCurrentLine: Bool, isPast: Bool, alignRight: Bool) -> some View {
        Text(line.text)
            .font(isCurrentLine ? .subheadline.weight(.semibold) : .subheadline)
            .foregroundStyle(isCurrentLine ? .primary : isPast ? .tertiary : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isCurrentLine
                          ? line.speaker.color.opacity(0.15)
                          : Color(.secondarySystemBackground).opacity(isPast ? 0.5 : 1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(isCurrentLine ? line.speaker.color.opacity(0.5) : Color.clear, lineWidth: 1.5)
                    )
            )
            .scaleEffect(isCurrentLine ? 1.02 : 1.0)
            .frame(maxWidth: .infinity, alignment: alignRight ? .trailing : .leading)
    }

    func errorView(_ msg: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text(msg)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Try Again") {
                Task { await engine.generate(context: podcastContext) }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            Spacer()
        }
    }

    // MARK: - Playback Bar

    @ViewBuilder
    var playbackBar: some View {
        switch engine.phase {
        case .ready(let lines) where !lines.isEmpty:
            // Ready to play
            HStack {
                Text("\(lines.count) exchanges")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    engine.play()
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.purple)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 16)

        case .playing(let idx):
            playingControls(idx: idx, isPaused: false)

        case .paused(let idx):
            playingControls(idx: idx, isPaused: true)

        default:
            EmptyView()
                .frame(height: 0)
        }
    }

    func playingControls(idx: Int, isPaused: Bool) -> some View {
        HStack(spacing: 24) {
            // Progress
            VStack(alignment: .leading, spacing: 2) {
                Text("\(idx + 1) / \(engine.allLines.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ProgressView(value: Double(idx + 1), total: Double(max(engine.allLines.count, 1)))
                    .tint(.purple)
                    .frame(width: 80)
            }

            Spacer()

            // Stop
            Button { engine.stop() } label: {
                Image(systemName: "stop.circle")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
            }

            // Play/Pause
            Button {
                isPaused ? engine.resume() : engine.pause()
            } label: {
                Image(systemName: isPaused ? "play.circle.fill" : "pause.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.purple)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
    }
}

// MARK: - Safe subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
