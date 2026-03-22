import SwiftUI

struct ArticleRowView: View {
    let link: Link

    private var statusColor: Color? {
        guard let status = link.status else { return nil }
        return StatusPill(status: status).color
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(link.title ?? link.url)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .lineLimit(3)

                HStack(spacing: 4) {
                    if let domain = link.domain {
                        Text(domain)
                            .foregroundStyle(.secondary)
                    }
                    if let savedAt = link.savedAt {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(savedAt.timeAgo)
                            .foregroundStyle(.tertiary)
                    }
                }
                .font(.caption)

                if let status = link.status {
                    StatusPill(status: status)
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)

            // Thumbnail
            thumbnailView
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(
            statusColor != nil
                ? statusColor!.opacity(0.06)
                : Color.clear
        )
    }

    // MARK: - Thumbnail

    @ViewBuilder
    var thumbnailView: some View {
        if let rawURL = link.image, let imageURL = URL(string: rawURL) {
            CachedAsyncImage(url: imageURL) { img in
                img.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                fallbackThumb
            }
        } else {
            fallbackThumb
        }
    }

    var fallbackThumb: some View {
        ZStack {
            LinearGradient(
                colors: domainGradient(for: link.domain),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if let first = link.domain?.first {
                Text(String(first).uppercased())
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
    }
}

// MARK: - Time Ago extension

extension Date {
    var timeAgo: String {
        let now = Date()
        let interval = now.timeIntervalSince(self)

        if interval < 60 { return "now" }
        if interval < 3600 { return "\(Int(interval / 60))m" }
        if interval < 86400 { return "\(Int(interval / 3600))h" }
        if interval < 604800 { return "\(Int(interval / 86400))d" }
        if interval < 2592000 { return "\(Int(interval / 604800))w" }
        return self.formatted(date: .abbreviated, time: .omitted)
    }
}
