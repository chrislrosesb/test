import SwiftUI

struct ArticleCardView: View {
    let link: Link
    @State private var isPressed = false

    private var hasImage: Bool {
        link.image != nil
    }

    private var statusGlowColor: Color? {
        guard let status = link.status else { return nil }
        return StatusPill(status: status).color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Inset image — fixed height, always full width
            Color.clear
                .frame(height: 200)
                .overlay {
                    if let rawURL = link.image, let imageURL = URL(string: rawURL) {
                        CachedAsyncImage(url: imageURL) { img in
                            img.resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            fallbackImage
                        }
                    } else {
                        fallbackImage
                    }
                }
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(8)

            // Title
            Text(link.title ?? link.url)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .lineLimit(3)
                .padding(.horizontal, 14)
                .padding(.top, 6)

            // Description
            if let desc = link.description, !desc.isEmpty {
                Text(desc)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .padding(.horizontal, 14)
                    .padding(.top, 3)
            }

            // Footer: favicon + domain + status + date
            HStack(spacing: 6) {
                if let rawFavicon = link.favicon, let faviconURL = URL(string: rawFavicon) {
                    AsyncImage(url: faviconURL) { phase in
                        if case .success(let img) = phase {
                            img.resizable()
                                .frame(width: 14, height: 14)
                                .clipShape(Circle())
                        }
                    }
                }
                if let domain = link.domain {
                    Text(domain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let status = link.status {
                    StatusPill(status: status)
                }
                Spacer()
                if let savedAt = link.savedAt {
                    Text(savedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(statusGlowColor?.opacity(0.5) ?? Color.white.opacity(0.08), lineWidth: statusGlowColor != nil ? 1.5 : 0.5)
        )
        .shadow(color: statusGlowColor?.opacity(0.3) ?? .clear, radius: 8, x: 0, y: 2)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(duration: 0.2, bounce: 0.5), value: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }

    // MARK: - Fallback

    var fallbackImage: some View {
        ZStack {
            LinearGradient(
                colors: domainGradient(for: link.domain),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if let first = link.domain?.first {
                Text(String(first).uppercased())
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.2))
            }
        }
    }
}

// MARK: - Status Badge (kept for other views that may use it)

struct StatusBadge: View {
    let status: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(.black.opacity(0.5)))
        .foregroundStyle(.white)
    }

    var label: String {
        switch status {
        case "to-read": return "To Read"
        case "to-try": return "To Try"
        case "to-share": return "To Share"
        case "done": return "Done"
        default: return status
        }
    }

    var icon: String {
        switch status {
        case "to-read": return "book"
        case "to-try": return "hammer"
        case "to-share": return "paperplane"
        case "done": return "checkmark.circle"
        default: return "circle"
        }
    }
}
