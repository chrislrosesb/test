import SwiftUI

struct TriageView: View {
    @Environment(LibraryViewModel.self) private var vm

    var unenrichedLinks: [Link] {
        // Un-enriched = no note and no tags and no category (Phase 2 will use Enrich AI)
        vm.allLinks.filter { $0.note == nil && ($0.tags == nil || $0.tags?.isEmpty == true) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if vm.allLinks.isEmpty && vm.isLoading {
                    ProgressView()
                } else if unenrichedLinks.isEmpty {
                    allCaughtUp
                } else {
                    triageStack
                }
            }
            .navigationTitle("Triage")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    var allCaughtUp: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
                .symbolEffect(.bounce)
            Text("All Caught Up!")
                .font(.title2)
                .fontWeight(.bold)
            Text("Every article has been reviewed.\nEnrich (AI) arrives in Phase 2.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var triageStack: some View {
        VStack(spacing: 20) {
            Text("\(unenrichedLinks.count) article\(unenrichedLinks.count == 1 ? "" : "s") to review")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Preview of unenriched articles
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(unenrichedLinks) { link in
                        ArticleCardView(link: link)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 12)
            }

            Text("AI Enrich — coming in Phase 2")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.bottom)
        }
    }
}
