import SwiftUI

struct TriageView: View {
    @Environment(LibraryViewModel.self) private var vm

    @State private var skippedIDs: Set<String> = []
    @State private var showEnrich = false

    var unenrichedLinks: [Link] {
        vm.allLinks.filter { $0.note == nil && ($0.tags == nil || $0.tags?.isEmpty == true) }
    }

    /// Show non-skipped first, then skipped at the end
    var sortedQueue: [Link] {
        let notSkipped = unenrichedLinks.filter { !skippedIDs.contains($0.id) }
        let skipped = unenrichedLinks.filter { skippedIDs.contains($0.id) }
        return notSkipped + skipped
    }

    var currentLink: Link? { sortedQueue.first }
    var total: Int { unenrichedLinks.count }
    var reviewed: Int { total - sortedQueue.filter { !skippedIDs.contains($0.id) }.count }

    var body: some View {
        NavigationStack {
            Group {
                if vm.allLinks.isEmpty && vm.isLoading {
                    ProgressView()
                } else if let link = currentLink {
                    triageContent(link: link)
                } else {
                    allCaughtUp
                }
            }
            .navigationTitle("Triage")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showEnrich) {
            if let link = currentLink {
                EnrichSheetView(link: link) { _ in
                    // After enrichment saves, the link gets note/tags
                    // so it drops out of unenrichedLinks automatically.
                    // Remove from skipped set if it was there.
                    skippedIDs.remove(link.id)
                }
                .environment(vm)
            }
        }
    }

    // MARK: - Triage Content

    func triageContent(link: Link) -> some View {
        VStack(spacing: 0) {
            // Counter
            HStack {
                Text("\(reviewed + 1) of \(total) to review")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if !skippedIDs.isEmpty {
                    Button {
                        withAnimation { skippedIDs.removeAll() }
                    } label: {
                        Text("Reset skipped")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)

            // Card
            ScrollView {
                ArticleCardView(link: link)
                    .padding(.horizontal, 16)
                    .id(link.id) // Forces view refresh when link changes
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }

            Spacer(minLength: 16)

            // Action buttons
            HStack(spacing: 16) {
                Button {
                    withAnimation(.spring(duration: 0.35, bounce: 0.3)) {
                        _ = skippedIDs.insert(link.id)
                    }
                } label: {
                    Label("Skip", systemImage: "arrow.right")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button {
                    showEnrich = true
                } label: {
                    Label("Enrich", systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .tint(.purple)
                .buttonStyle(.borderedProminent)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - All Caught Up

    var allCaughtUp: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
                .symbolEffect(.bounce)
            Text("All Caught Up!")
                .font(.title2)
                .fontWeight(.bold)
            Text("Every article has been reviewed.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
