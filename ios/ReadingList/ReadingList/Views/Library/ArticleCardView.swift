import SwiftUI

struct ArticleCardView: View {
    let link: Link

    var body: some View {
        ZStack(alignment: .bottom) {
            cardBackground
                .frame(height: 220)

            cardOverlay
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
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

    @ViewBuilder
    var fallbackBackground: some View {
        ZStack {
            LinearGradient(
                colors: domainGradient(for: link.domain),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if let first = link.domain?.first {
                Text(String(first).uppercased())
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.18))
            }
        }
    }

    // MARK: - Overlay

    @ViewBuilder
    var cardOverlay: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title
            Text(link.title ?? link.url)
                .font(.headline)
                .lineLimit(2)
                .foregroundStyle(.white)

            // Meta row
            HStack(spacing: 6) {
                faviconAndDomain

                Spacer()

                if let stars = link.stars, stars > 0 {
                    starRow(stars: stars)
                }

                if let status = link.status {
                    StatusPill(status: status)
                }
            }

            // Tags
            if let tags = link.tags, !tags.isEmpty {
                Text(tags)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
            }

            // Note preview
            if let note = link.note, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { glassOverlay }
    }

    @ViewBuilder
    var glassOverlay: some View {
        if #available(iOS 26, *) {
            Rectangle().glassEffect(.regular)
        } else {
            Rectangle().fill(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    var faviconAndDomain: some View {
        HStack(spacing: 5) {
            if let rawFavicon = link.favicon, let faviconURL = URL(string: rawFavicon) {
                AsyncImage(url: faviconURL) { phase in
                    if case .success(let img) = phase {
                        img.resizable()
                            .frame(width: 14, height: 14)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
            }
            if let domain = link.domain {
                Text(domain)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    func starRow(stars: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: i <= stars ? "star.fill" : "star")
                    .font(.system(size: 9))
                    .foregroundStyle(i <= stars ? .yellow : .white.opacity(0.4))
            }
        }
    }
}
