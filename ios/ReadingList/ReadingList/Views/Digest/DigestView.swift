import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

enum DigestPhase {
    case idle
    case generating
    case ready(String)
    case unavailable(String)
    case error(String)
}

struct DigestView: View {
    @Environment(LibraryViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    @State private var phase: DigestPhase = .idle
    @State private var selectedLink: Link? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Today's Reading")
                            .font(.largeTitle)
                            .fontWeight(.black)

                        Text(Date(), style: .date)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 16) {
                            digestStat(count: vm.allLinks.filter { $0.status == "to-read" }.count, label: "to read", color: .blue)
                            digestStat(count: vm.allLinks.filter { $0.status == "to-try" }.count, label: "to do", color: .orange)
                            digestStat(count: vm.allLinks.filter { $0.status == "done" }.count, label: "done", color: .green)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    if vm.todaysLinks.isEmpty {
                        ContentUnavailableView(
                            "Nothing saved today yet",
                            systemImage: "tray",
                            description: Text("Articles you save today will appear here.")
                        )
                        .padding(.top, 40)
                    } else {
                        // AI Narrative card
                        aiNarrativeCard
                            .padding(.horizontal, 16)

                        // Saved Today list
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Saved Today")
                                .font(.title3)
                                .fontWeight(.bold)
                                .padding(.horizontal, 20)

                            ForEach(vm.todaysLinks) { link in
                                ArticleCardView(link: link)
                                    .padding(.horizontal, 16)
                                    .contentShape(Rectangle())
                                    .onTapGesture { selectedLink = link }
                            }
                        }
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
        }
        .fullScreenCover(item: $selectedLink) { link in
            if let idx = vm.todaysLinks.firstIndex(where: { $0.id == link.id }) {
                ArticleReaderContainer(links: vm.todaysLinks, initialIndex: idx, vm: vm)
            }
        }
    }

    // MARK: - AI Narrative Card

    @ViewBuilder
    var aiNarrativeCard: some View {
        switch phase {
        case .idle:
            Button {
                Task { await generateDigest() }
            } label: {
                Label("Generate Today's Summary", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)

        case .generating:
            HStack(spacing: 12) {
                ProgressView().scaleEffect(0.9)
                Text("Analysing today's saves…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

        case .ready(let text):
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("AI Summary", systemImage: "sparkles")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.purple)
                    Spacer()
                    Button {
                        Task { await generateDigest() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(text)
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
                Label("Summary failed", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .fontWeight(.semibold)
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Try Again") { Task { await generateDigest() } }
                    .font(.caption)
                    .tint(.indigo)
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - AI Logic

    func generateDigest() async {
        guard !vm.todaysSavedContext.isEmpty else {
            phase = .unavailable("Nothing saved today — check back later.")
            return
        }
        phase = .generating
        if #available(iOS 26, *) {
            await runFoundationModelsDigest()
        } else {
            phase = .unavailable("AI Digest requires iOS 26 and Apple Intelligence.")
        }
    }

    @available(iOS 26, *)
    func runFoundationModelsDigest() async {
        #if canImport(FoundationModels)
        let prompt = """
        Here are the articles I saved to my reading list today:

        \(vm.todaysSavedContext)

        In 3-4 conversational sentences:
        1. What themes or topics emerged from today's saves?
        2. Which one looks most worth reading first, and why?
        3. Any quick observation about the mix (e.g., very technical today, lots of design content)?

        Be direct and personal, like a smart friend giving a quick take on my reading pile. \
        No bullet points — flowing prose only.
        """
        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            phase = .ready(response.content.trimmingCharacters(in: .whitespacesAndNewlines))
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

    // MARK: - Helpers

    func digestStat(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
