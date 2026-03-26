import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

private enum SynthesisPhase {
    case idle
    case generating
    case ready(synthesis: String, gaps: String, nextStep: String, sources: [Link])
    case unavailable(String)
    case error(String)
}

struct KnowledgeSynthesisView: View {
    @Environment(LibraryViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var phase: SynthesisPhase = .idle
    @State private var selectedLink: Link? = nil
    @FocusState private var queryFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    querySection
                    resultSection
                    Spacer(minLength: 40)
                }
                .padding(.bottom, 40)
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear { queryFocused = true }
        }
        .fullScreenCover(item: $selectedLink) { link in
            ArticleReaderContainer(links: [link], initialIndex: 0, vm: vm)
        }
    }

    // MARK: - Header

    var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Knowledge Synthesis")
                .font(.largeTitle)
                .fontWeight(.black)
            Text("Ask what you know about any topic in your library")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Query Input

    var querySection: some View {
        HStack(spacing: 12) {
            TextField("What do I know about…", text: $query)
                .textFieldStyle(.plain)
                .font(.body)
                .focused($queryFocused)
                .submitLabel(.search)
                .onSubmit { startSynthesis() }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

            Button {
                startSynthesis()
            } label: {
                Image(systemName: "sparkles")
                    .font(.body.weight(.semibold))
                    .padding(11)
                    .background(
                        query.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Color.indigo.opacity(0.4)
                            : Color.indigo,
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .foregroundStyle(.white)
            }
            .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Result

    @ViewBuilder
    var resultSection: some View {
        switch phase {
        case .idle:
            idleHints

        case .generating:
            HStack(spacing: 12) {
                ProgressView().scaleEffect(0.9)
                Text("Searching your library…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .padding(.horizontal, 16)

        case .ready(let synthesis, let gaps, let nextStep, let sources):
            synthesisCards(synthesis: synthesis, gaps: gaps, nextStep: nextStep, sources: sources)

        case .unavailable(let msg):
            Label(msg, systemImage: "sparkles.slash")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 16)

        case .error(let msg):
            VStack(alignment: .leading, spacing: 8) {
                Label("Synthesis failed", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .fontWeight(.semibold)
                Text(msg).font(.caption).foregroundStyle(.secondary)
                Button("Try Again") { startSynthesis() }
                    .font(.subheadline).tint(.indigo)
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Idle Hints

    var idleHints: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Try asking:")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 20)

            let examples = [
                "What do I know about LLMs?",
                "What have I read about productivity?",
                "Summarise my reading on SwiftUI",
                "What do I know about startups?"
            ]
            ForEach(examples, id: \.self) { example in
                Button {
                    query = example
                    startSynthesis()
                } label: {
                    HStack {
                        Text(example)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.circle")
                            .foregroundStyle(.indigo)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Synthesis Cards

    @ViewBuilder
    func synthesisCards(synthesis: String, gaps: String, nextStep: String, sources: [Link]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Synthesis
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Synthesis", systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.purple)
                    Spacer()
                    Button { startSynthesis() } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(synthesis).font(.subheadline)
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

            // Gaps
            if !gaps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Gaps in Your Knowledge", systemImage: "questionmark.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text(gaps).font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            }

            // Next Step
            if !nextStep.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Next Step", systemImage: "arrow.right.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                    Text(nextStep).font(.subheadline)
                }
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            }

            // Sources
            if !sources.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Sources (\(sources.count))")
                        .font(.headline)

                    ForEach(sources) { link in
                        Button {
                            selectedLink = link
                        } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(link.title ?? link.url)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    HStack(spacing: 6) {
                                        if let domain = link.domain {
                                            Text(domain)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        if ArticleFullTextStore.shared.fetch(linkId: link.id) != nil {
                                            Label("Full text", systemImage: "doc.text.fill")
                                                .font(.caption2)
                                                .foregroundStyle(.indigo)
                                        }
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(12)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Logic

    func startSynthesis() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        queryFocused = false
        phase = .generating
        Task { await runSynthesis(query: q) }
    }

    func runSynthesis(query: String) async {
        if #available(iOS 26, *) {
            await runFoundationModelsSynthesis(query: query)
        } else {
            phase = .unavailable("Knowledge Synthesis requires iOS 26 and Apple Intelligence.")
        }
    }

    @available(iOS 26, *)
    func runFoundationModelsSynthesis(query: String) async {
        #if canImport(FoundationModels)
        let (links, context) = buildContext(for: query)

        guard !links.isEmpty else {
            phase = .unavailable("No articles in your library match \"\(query)\". Try a broader search term.")
            return
        }

        let prompt = """
        My question: "\(query)"

        Here are \(links.count) relevant articles from my personal reading library:

        \(context)

        Respond with exactly these three labelled sections:

        SYNTHESIS:
        2-3 paragraphs synthesising what I know about "\(query)" based on these sources. Reference specific articles by title. Write as if briefing me before a meeting on this topic — direct, concrete, no filler.

        GAPS:
        1-2 sentences on what's missing or unclear in my understanding based on what I've saved so far.

        NEXT STEP:
        One concrete action I could take this week related to this topic.

        Use "you" throughout. Be specific and reference actual article titles.
        """

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            let (synthesis, gaps, nextStep) = parseSynthesisResponse(response.content)
            phase = .ready(synthesis: synthesis, gaps: gaps, nextStep: nextStep, sources: links)
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

    // MARK: - Context Builder

    /// Scores all library articles for relevance to the query.
    /// Uses stored digests when available, falls back to summary + note.
    func buildContext(for query: String) -> (links: [Link], context: String) {
        let stopWords: Set<String> = [
            "what", "do", "i", "know", "about", "tell", "me", "explain",
            "show", "find", "summarise", "summarize", "my", "reading", "on",
            "the", "a", "an", "and", "or", "for", "to", "in", "of", "with"
        ]
        let tokens = query.lowercased()
            .split(separator: " ")
            .map(String.init)
            .filter { !stopWords.contains($0) && $0.count > 2 }

        guard !tokens.isEmpty else { return ([], "") }

        let store = ArticleFullTextStore.shared
        var scored: [(link: Link, score: Int, contextText: String)] = []

        for link in vm.allLinks {
            let baseMeta = [
                link.title, link.description, link.note,
                link.summary, link.tags, link.category
            ]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()

            let fullText = store.fetch(linkId: link.id)
            let searchHaystack = fullText != nil
                ? baseMeta + " " + fullText!.digest.lowercased()
                : baseMeta

            let matches = tokens.filter { searchHaystack.contains($0) }.count
            guard matches > 0 else { continue }

            var score = matches * 10
            let titleLower = (link.title ?? "").lowercased()
            score += tokens.filter { titleLower.contains($0) }.count * 5
            if fullText != nil { score += 3 }
            if (link.stars ?? 0) >= 4 { score += 5 }

            var contextParts: [String] = []
            if let ft = fullText, !ft.digest.isEmpty {
                contextParts.append(ft.digest)
            } else {
                if let s = link.summary, !s.isEmpty { contextParts.append("Summary: \(s)") }
                if let n = link.note, !n.isEmpty { contextParts.append("My note: \(n)") }
            }

            scored.append((link, score, contextParts.joined(separator: "\n")))
        }

        let top = scored.sorted { $0.score > $1.score }.prefix(12)
        guard !top.isEmpty else { return ([], "") }

        let links = top.map(\.link)
        let context = top.enumerated().map { i, item in
            var s = "\(i + 1). \"\(item.link.title ?? item.link.url)\" (\(item.link.domain ?? "unknown"))"
            if !item.contextText.isEmpty {
                s += "\n\(item.contextText)"
            }
            return s
        }.joined(separator: "\n\n")

        return (links, context)
    }

    // MARK: - Response Parser

    func parseSynthesisResponse(_ raw: String) -> (synthesis: String, gaps: String, nextStep: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let synthRange = text.range(of: "SYNTHESIS:", options: .caseInsensitive),
              let gapsRange  = text.range(of: "GAPS:", options: .caseInsensitive) else {
            return (text, "", "")
        }

        let synthesis = String(text[synthRange.upperBound..<gapsRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let gaps: String
        let nextStep: String

        if let nextRange = text.range(of: "NEXT STEP:", options: .caseInsensitive) {
            gaps = String(text[gapsRange.upperBound..<nextRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            nextStep = String(text[nextRange.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            gaps = String(text[gapsRange.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            nextStep = ""
        }

        return (synthesis, gaps, nextStep)
    }
}
