import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

private enum NotesRange: String, CaseIterable, Identifiable {
    case week      = "7 Days"
    case month     = "30 Days"
    case quarter   = "3 Months"
    case thisMonth = "This Month"

    var id: String { rawValue }

    var dateRange: (start: Date, end: Date) {
        let now = Date()
        switch self {
        case .week:
            return (now.addingTimeInterval(-604_800), now)
        case .month:
            return (now.addingTimeInterval(-2_592_000), now)
        case .quarter:
            return (now.addingTimeInterval(-7_776_000), now)
        case .thisMonth:
            let start = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: now)) ?? now
            return (start, now)
        }
    }
}

private enum NotesPhase {
    case idle
    case generating
    case ready(recap: String, actionItems: [String])
    case unavailable(String)
    case error(String)
}

struct NotesReviewView: View {
    @Environment(LibraryViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    @State private var selectedRange: NotesRange = .week
    @State private var phase: NotesPhase = .idle
    @State private var selectedLink: Link? = nil

    private var dateRange: (start: Date, end: Date) { selectedRange.dateRange }
    private var notedLinks: [Link] { vm.notedLinks(from: dateRange.start, to: dateRange.end) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    pickerSection

                    if notedLinks.isEmpty {
                        ContentUnavailableView(
                            "No notes in this period",
                            systemImage: "note.text",
                            description: Text("Add notes to articles and they'll appear here.")
                        )
                        .padding(.top, 30)
                    } else {
                        aiAnalysisCard
                            .padding(.horizontal, 16)

                        if case .ready(_, let items) = phase, !items.isEmpty {
                            actionItemsSection(items)
                        }

                        Divider().padding(.horizontal, 16)

                        articlesSection
                    }

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
            .onChange(of: selectedRange) { _, _ in
                phase = .idle
            }
        }
        .fullScreenCover(item: $selectedLink) { link in
            if let idx = notedLinks.firstIndex(where: { $0.id == link.id }) {
                ArticleReaderContainer(links: notedLinks, initialIndex: idx, vm: vm)
            }
        }
    }

    // MARK: - Header

    var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Notes Review")
                .font(.largeTitle)
                .fontWeight(.black)
            Text("\(notedLinks.count) article\(notedLinks.count == 1 ? "" : "s") with notes")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Picker

    var pickerSection: some View {
        Picker("Range", selection: $selectedRange) {
            ForEach(NotesRange.allCases) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
    }

    // MARK: - AI Analysis Card

    @ViewBuilder
    var aiAnalysisCard: some View {
        switch phase {
        case .idle:
            Button {
                Task { await generateAnalysis() }
            } label: {
                Label("Analyse Notes", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)

        case .generating:
            HStack(spacing: 12) {
                ProgressView().scaleEffect(0.9)
                Text("Reading your notes…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

        case .ready(let recap, _):
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("AI Recap", systemImage: "sparkles")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.purple)
                    Spacer()
                    Button {
                        Task { await generateAnalysis() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(recap)
                    .font(.subheadline)
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

        case .unavailable(let msg):
            Label(msg, systemImage: "sparkles.slash")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

        case .error(let msg):
            VStack(alignment: .leading, spacing: 8) {
                Label("Analysis failed", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .fontWeight(.semibold)
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Try Again") { Task { await generateAnalysis() } }
                    .font(.caption)
                    .tint(.indigo)
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Action Items

    func actionItemsSection(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Action Items")
                .font(.headline)
                .padding(.horizontal, 20)

            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(i + 1)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.indigo, in: Circle())
                    Text(item)
                        .font(.subheadline)
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Articles List

    var articlesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Articles with Notes")
                .font(.title3)
                .fontWeight(.bold)
                .padding(.horizontal, 20)

            ForEach(notedLinks) { link in
                ArticleCardView(link: link)
                    .padding(.horizontal, 16)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedLink = link }
            }
        }
    }

    // MARK: - AI Logic

    func generateAnalysis() async {
        let context = vm.notesContext(from: dateRange.start, to: dateRange.end)
        guard !context.isEmpty else {
            phase = .unavailable("No notes found in this period.")
            return
        }
        phase = .generating
        if #available(iOS 26, *) {
            await runFoundationModelsNotes()
        } else {
            phase = .unavailable("Notes Review requires iOS 26 and Apple Intelligence.")
        }
    }

    @available(iOS 26, *)
    func runFoundationModelsNotes() async {
        #if canImport(FoundationModels)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let formattedStart = formatter.string(from: dateRange.start)
        let formattedEnd   = formatter.string(from: dateRange.end)
        let context        = vm.notesContext(from: dateRange.start, to: dateRange.end)

        let prompt = """
        Here are articles I saved between \(formattedStart) and \(formattedEnd), \
        along with my personal notes on each one:

        \(context)

        Respond with two clearly labelled sections:

        RECAP:
        2-3 paragraphs summarising what I was thinking about and engaging with during this period. \
        What ideas kept coming up? What was I trying to learn or decide? \
        Reference specific notes where relevant — this should feel like reading back a personal journal entry.

        ACTION ITEMS:
        Up to 5 specific follow-ups I flagged in my notes that I should act on. \
        Only include items genuinely suggested by my notes — don't invent things. \
        If fewer than 5 are present, list only what's there. \
        Format each as a single sentence starting with a verb.

        Be personal and direct. Use "you" and quote or paraphrase my actual notes.
        """

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            let (recap, actionItems) = parseNotesResponse(response.content)
            phase = .ready(recap: recap, actionItems: actionItems)
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

    func parseNotesResponse(_ raw: String) -> (recap: String, actionItems: [String]) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let recapRange  = text.range(of: "RECAP:", options: .caseInsensitive),
              let actionRange = text.range(of: "ACTION ITEMS:", options: .caseInsensitive) else {
            return (text, [])
        }

        let recap = String(text[recapRange.upperBound..<actionRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let actionBlock = String(text[actionRange.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let actionItems = actionBlock
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { line -> String in
                var result = line
                if let range = result.range(of: #"^(\d+\.\s*|[-•]\s*)"#, options: .regularExpression) {
                    result = String(result[range.upperBound...])
                }
                return result
            }

        return (recap, actionItems)
    }
}
