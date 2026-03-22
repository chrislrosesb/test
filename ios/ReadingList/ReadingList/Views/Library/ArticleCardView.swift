import SwiftUI

struct ArticleCardView: View {
    let link: Link

    private let cardHeight: CGFloat = 270
    private let cornerRadius: CGFloat = 28

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Layer 1: Background
            cardBackground

            // Layer 2: Gradient scrim (bottom 55%)
            VStack {
                Spacer()
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black.opacity(0.72), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: cardHeight * 0.58)
            }

            // Layer 3: Bottom text
            VStack {
                Spacer()
                bottomContent
            }

            // Layer 4: Status badge (top-left, only if status set)
            if let status = link.status {
                StatusBadge(status: status)
                    .padding(14)
            }
        }
        .frame(height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.22), radius: 14, x: 0, y: 7)
    }

    // MARK: - Background

    @ViewBuilder
    var cardBackground: some View {
        if let rawURL = link.image, let imageURL = URL(string: rawURL) {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().aspectRatio(contentMode: .fill)
                default:
                    fallbackBackground
                }
            }
        } else {
            fallbackBackground
        }
    }

    var fallbackBackground: some View {
        ZStack {
            LinearGradient(
                colors: domainGradient(for: link.domain),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if let first = link.domain?.first {
                Text(String(first).uppercased())
                    .font(.system(size: 96, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.15))
            }
        }
    }

    // MARK: - Bottom text

    var bottomContent: some View {
        VStack(spacing: 5) {
            Text(link.title ?? link.url)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)

            HStack(spacing: 5) {
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
                        .foregroundStyle(.white.opacity(0.78))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.bottom, 20)
    }
}

// MARK: - Status Badge (Apple Invites "Hosting" pill style)

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
        .background { badgeBackground }
        .foregroundStyle(.white)
    }

    @ViewBuilder
    var badgeBackground: some View {
        if #available(iOS 26, *) {
            Capsule().glassEffect(.regular)
        } else {
            Capsule().fill(.ultraThinMaterial)
        }
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
