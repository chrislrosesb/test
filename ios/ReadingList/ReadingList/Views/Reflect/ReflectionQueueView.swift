import SwiftUI

struct ReflectionQueueView: View {
    @Environment(LibraryViewModel.self) private var vm
    @State private var reflectLink: Link? = nil

    private var store: ReflectionStore { ReflectionStore.shared }

    var pendingLinks: [Link] {
        store.pendingLinks(from: vm.allLinks)
    }

    var body: some View {
        NavigationStack {
            Group {
                if pendingLinks.isEmpty {
                    ContentUnavailableView(
                        "Nothing Pending",
                        systemImage: "sparkles.rectangle.stack",
                        description: Text("Articles you save for later will appear here.")
                    )
                } else {
                    List {
                        ForEach(pendingLinks) { link in
                            reflectRow(link: link)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Reflect Queue")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(item: $reflectLink) { link in
            ReflectionView(link: link, vm: vm) {
                reflectLink = nil
            }
        }
    }

    func reflectRow(link: Link) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(link.title ?? link.url)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    if let domain = link.domain {
                        Text(domain).foregroundStyle(.secondary)
                    }
                    if let queuedAt = store.queuedAt(linkId: link.id) {
                        Text("·").foregroundStyle(.tertiary)
                        Text(queuedAt.timeAgo).foregroundStyle(.tertiary)
                    }
                }
                .font(.caption)

                // Depth score
                let score = store.depthScore(for: link)
                HStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .font(.system(size: 9))
                        .foregroundStyle(store.depthColor(score: score))
                    Text("Depth \(score)")
                        .font(.caption2)
                        .foregroundStyle(store.depthColor(score: score))
                }
                .padding(.top, 2)
            }

            Spacer()

            Button("Reflect") {
                reflectLink = link
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.teal)
            .font(.subheadline)
            .fontWeight(.semibold)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}
