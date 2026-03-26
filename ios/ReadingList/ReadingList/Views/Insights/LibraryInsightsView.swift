import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

private enum InsightsPhase {
    case idle
    case generating
    case ready(narrative: String, actionItems: [String], generatedAt: Date)
    case unavailable(String)
    case error(String)
}

struct LibraryInsightsView: View {
    @Environment(LibraryViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    @State private var phase: InsightsPhase = .idle

    // MARK: - Derived stats (computed once, no AI needed)

    private var toReadCount: Int  { vm.allLinks.filter { $0.status == "to-read" }.count }
    private var toDoCount: Int    { vm.allLinks.filter { $0.status == "to-try" }.count }
    private var doneCount: Int    { vm.allLinks.filter { $0.status == "done" }.count }
    private var unsortedCount: Int { vm.allLinks.count - toReadCount - toDoCount - doneCount }
    private var starredCount: Int { vm.allLinks.filter { ($0.stars ?? 0) >= 4 }.count }

    private var topCategories: [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        for link in vm.allLinks { if let c = link.category { counts[c, default: 0] += 1 } }
        return counts.sorted { $0.value > $1.value }.prefix(3).map { (name: $0.key, count: $0.value) }
    }

    private var topTags: [(tag: String, count: Int)] {
        Array(vm.tagCounts.prefix(5))
    }

    private var libraryAge: String {
        guard let oldest = vm.allLinks.compactMap(\.savedAt).min() else { return "unknown" }
        let days = Calendar.current.dateComponents([.day], from: oldest, to: Date()).day ?? 0
        return days < 14 ? "\(days) days" : "\(days / 7) weeks"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    statsSection
                    Divider().padding(.horizontal, 16)
                    aiSection
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
        }
    }

    // MARK: - Header

    var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Library Insights")
                .font(.largeTitle)
                .fontWeight(.black)
            Text("\(vm.allLinks.count) articles · \(libraryAge) of saves")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Stats Overview (always visible)

    var statsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Status grid
            VStack(alignment: .leading, spacing: 10) {
                Text("Status")
                    .font(.headline)
                    .padding(.horizontal, 20)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    statCard(value: toReadCount, label: "To Read", color: .blue)
                    statCard(value: toDoCount,   label: "To Do",   color: .orange)
                    statCard(value: doneCount,   label: "Done",    color: .green)
                    statCard(value: unsortedCount, label: "Unsorted", color: .secondary)
                }
                .padding(.horizontal, 16)
            }

            // Top categories
            if !topCategories.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Top Categories")
                        .font(.headline)
                        .padding(.horizontal, 20)

                    ForEach(topCategories, id: \.name) { cat in
                        HStack {
                            Text(cat.name)
                                .font(.subheadline)
                            Spacer()
                            Text("\(cat.count)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }

            // Top tags
            if !topTags.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Top Tags")
                        .font(.headline)
                        .padding(.horizontal, 20)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(topTags, id: \.tag) { item in
                                Text("\(item.tag) \(item.count)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.indigo.opacity(0.12), in: Capsule())
                                    .foregroundStyle(.indigo)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
    }

    func statCard(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - AI Section

    var aiSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What your library says about you")
                .font(.headline)
                .padding(.horizontal, 20)

            aiNarrativeCard
                .padding(.horizontal, 16)

            if case .ready(_, let actionItems, _) = phase, !actionItems.isEmpty {
                actionItemsSection(actionItems)
            }
        }
    }

    @ViewBuilder
    var aiNarrativeCard: some View {
        switch phase {
        case .idle:
            Button {
                Task { await generateInsights() }
            } label: {
                Label("Generate Insights", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)

        case .generating:
            HStack(spacing: 12) {
                ProgressView().scaleEffect(0.9)
                Text("Analysing your library…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

        case .ready(let narrative, _, let generatedAt):
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("AI Analysis", systemImage: "sparkles")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.purple)
                    Spacer()
                    Text(generatedAt, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Button {
                        Task { await generateInsights() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(narrative)
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
                Button("Try Again") { Task { await generateInsights() } }
                    .font(.caption)
                    .tint(.indigo)
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
    }

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

    // MARK: - AI Logic

    func generateInsights() async {
        guard !vm.libraryStatsContext.isEmpty, vm.allLinks.count > 0 else {
            phase = .unavailable("Add some articles first.")
            return
        }
        phase = .generating
        if #available(iOS 26, *) {
            await runFoundationModelsInsights()
        } else {
            phase = .unavailable("AI Insights requires iOS 26 and Apple Intelligence.")
        }
    }

    @available(iOS 26, *)
    func runFoundationModelsInsights() async {
        #if canImport(FoundationModels)
        let prompt = """
        Here are statistics about my personal reading list library:

        \(vm.libraryStatsContext)

        Respond with two clearly labelled sections:

        NARRATIVE:
        2-3 paragraphs about what these statistics reveal about my reading habits and interests right now. \
        What am I gravitating toward? What does the tag/category mix suggest about my current focus? \
        Be specific about the numbers, not generic.

        ACTION ITEMS:
        Exactly 3 specific, actionable suggestions based on the data. \
        Format each as a single sentence starting with a verb. \
        Focus on what I should do with my backlog.

        Be direct and personal. Use "you" and reference the actual numbers.
        """
        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            let (narrative, actionItems) = parseInsightsResponse(response.content)
            phase = .ready(narrative: narrative, actionItems: actionItems, generatedAt: Date())
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

    func parseInsightsResponse(_ raw: String) -> (narrative: String, actionItems: [String]) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let narrativeRange = text.range(of: "NARRATIVE:", options: .caseInsensitive),
              let actionRange   = text.range(of: "ACTION ITEMS:", options: .caseInsensitive) else {
            // Fallback: treat whole response as narrative
            return (text, [])
        }

        let narrative = String(text[narrativeRange.upperBound..<actionRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let actionBlock = String(text[actionRange.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let actionItems = actionBlock
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { line -> String in
                // Strip leading "1. ", "2. ", "- ", "• " etc.
                var result = line
                if let range = result.range(of: #"^(\d+\.\s*|[-•]\s*)"#, options: .regularExpression) {
                    result = String(result[range.upperBound...])
                }
                return result
            }

        return (narrative, actionItems)
    }
}
