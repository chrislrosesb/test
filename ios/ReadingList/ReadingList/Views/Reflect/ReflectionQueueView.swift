import SwiftUI

struct ReflectionQueueView: View {
    @Environment(LibraryViewModel.self) private var vm
    @State private var reflectLink: Link? = nil

    private var store: ReflectionStore { ReflectionStore.shared }

    var pendingLinks: [Link] {
        store.pendingLinks(from: vm.allLinks)
    }

    // Up to 6 random articles the user hasn't reflected on yet
    var suggestedLinks: [Link] {
        vm.allLinks
            .filter { !store.isReflected($0.id) && !store.isPending($0.id) }
            .shuffled()
            .prefix(6)
            .map { $0 }
    }

    var totalReflected: Int { store.reflectedIds.count }

    var averageDepth: Int {
        guard !vm.allLinks.isEmpty else { return 0 }
        let total = vm.allLinks.reduce(0) { $0 + store.depthScore(for: $1) }
        return total / vm.allLinks.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    statsHeader

                    if !pendingLinks.isEmpty {
                        articleSection(
                            title: "Saved for Later",
                            icon: "clock",
                            color: .orange,
                            links: pendingLinks
                        )
                    }

                    articleSection(
                        title: pendingLinks.isEmpty ? "Reflect on Something" : "Explore More",
                        icon: "sparkles",
                        color: .teal,
                        links: suggestedLinks
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .navigationTitle("Reflect")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground))
        }
        .sheet(item: $reflectLink) { link in
            ReflectionView(link: link, vm: vm) {
                reflectLink = nil
            }
        }
    }

    // MARK: - Stats header

    var statsHeader: some View {
        HStack(spacing: 12) {
            statCard(
                value: store.currentStreak > 0 ? "\(store.currentStreak)" : "—",
                label: "day streak",
                icon: store.currentStreak > 0 ? "flame.fill" : "flame",
                color: store.currentStreak > 0 ? .orange : .secondary
            )
            statCard(
                value: "\(totalReflected)",
                label: "reflected",
                icon: "checkmark.circle.fill",
                color: .teal
            )
            statCard(
                value: "\(averageDepth)",
                label: "avg depth",
                icon: "waveform",
                color: store.depthColor(score: averageDepth)
            )
        }
    }

    func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Article sections

    func articleSection(title: String, icon: String, color: Color, links: [Link]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 4)

            if links.isEmpty {
                Text("Nothing here yet — start reading and mark articles as done.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            } else {
                ForEach(links) { link in
                    reflectRow(link: link)
                }
            }
        }
    }

    // MARK: - Row

    func reflectRow(link: Link) -> some View {
        let score = store.depthScore(for: link)
        let color = store.depthColor(score: score)

        return HStack(spacing: 12) {
            // Depth ring
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 3)
                    .frame(width: 36, height: 36)
                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 36, height: 36)
                Text("\(score)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 3) {
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
            }

            Spacer()

            Button("Reflect") {
                reflectLink = link
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.teal)
            .font(.subheadline)
            .fontWeight(.semibold)
            .controlSize(.small)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}
