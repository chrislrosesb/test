import WidgetKit
import SwiftUI

// MARK: - Data

struct WidgetLink: Codable {
    let title: String?
    let domain: String?
    let status: String?
    let image: String?
    let savedAt: Date?

    enum CodingKeys: String, CodingKey {
        case title, domain, status, image
        case savedAt = "saved_at"
    }
}

// MARK: - Timeline Entry

struct ReadingEntry: TimelineEntry {
    let date: Date
    let articles: [WidgetArticle]
}

struct WidgetArticle: Identifiable {
    let id = UUID()
    let title: String
    let domain: String
    let timeAgo: String
    let imageURL: URL?
    let statusLabel: String?
}

// MARK: - Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> ReadingEntry {
        ReadingEntry(date: .now, articles: [
            WidgetArticle(title: "Loading your articles...", domain: "procrastinate", timeAgo: "now", imageURL: nil, statusLabel: "To Read"),
            WidgetArticle(title: "Pull to refresh in the app", domain: "procrastinate", timeAgo: "now", imageURL: nil, statusLabel: nil),
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (ReadingEntry) -> ()) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReadingEntry>) -> ()) {
        Task {
            let entry = await fetchEntry()
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    func fetchEntry() async -> ReadingEntry {
        let baseURL = "https://ownqyyfgferczpdgihgr.supabase.co"
        let anonKey = "sb_publishable_RPJSQlVO4isbKnZve8NlWg_55EO350Y"

        guard var comps = URLComponents(string: "\(baseURL)/rest/v1/links") else {
            return ReadingEntry(date: .now, articles: [])
        }

        comps.queryItems = [
            URLQueryItem(name: "select", value: "title,domain,status,image,saved_at"),
            URLQueryItem(name: "order", value: "saved_at.desc"),
            URLQueryItem(name: "limit", value: "3"),
            URLQueryItem(name: "private", value: "eq.false")
        ]

        guard let url = comps.url else {
            return ReadingEntry(date: .now, articles: [])
        }

        var req = URLRequest(url: url)
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        if let token = UserDefaults.standard.string(forKey: "supabase_access_token") {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let decoder = JSONDecoder()
            let frac = ISO8601DateFormatter()
            frac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            decoder.dateDecodingStrategy = .custom { decoder in
                let c = try decoder.singleValueContainer()
                let s = try c.decode(String.self)
                if let d = frac.date(from: s) { return d }
                if let d = plain.date(from: s) { return d }
                return Date()
            }

            let links = try decoder.decode([WidgetLink].self, from: data)
            let articles = links.map { link in
                WidgetArticle(
                    title: link.title ?? "Untitled",
                    domain: link.domain ?? "",
                    timeAgo: timeAgo(from: link.savedAt),
                    imageURL: link.image.flatMap { URL(string: $0) },
                    statusLabel: statusLabel(for: link.status)
                )
            }
            return ReadingEntry(date: .now, articles: articles)
        } catch {
            return ReadingEntry(date: .now, articles: [])
        }
    }

    func timeAgo(from date: Date?) -> String {
        guard let date else { return "" }
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        if interval < 604800 { return "\(Int(interval / 86400))d ago" }
        return "\(Int(interval / 604800))w ago"
    }

    func statusLabel(for status: String?) -> String? {
        switch status {
        case "to-read": return "To Read"
        case "to-try": return "To Do"
        case "done": return "Done"
        default: return nil
        }
    }
}

// MARK: - Widget View

struct ReadlingListWidgetEntryView: View {
    var entry: ReadingEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: "Procrastinate Next" + app icon
            HStack(alignment: .center) {
                Text("Procrastinate Next")
                    .font(.system(size: family == .systemSmall ? 14 : 17, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: family == .systemSmall ? 14 : 18))
                    .foregroundStyle(.indigo)
            }
            .padding(.bottom, family == .systemSmall ? 6 : 10)

            // Article rows
            let count = family == .systemSmall ? 1 : 2
            ForEach(Array(entry.articles.prefix(count).enumerated()), id: \.element.id) { index, article in
                articleRow(article)
                if index < count - 1 && index < entry.articles.count - 1 {
                    Spacer(minLength: 6)
                }
            }

            Spacer(minLength: 0)
        }
    }

    func articleRow(_ article: WidgetArticle) -> some View {
        HStack(spacing: 12) {
            // Square thumbnail
            Group {
                if let imageURL = article.imageURL {
                    // WidgetKit doesn't support AsyncImage — use placeholder
                    // The image will show after WidgetKit caches it
                    Color(.systemGray4)
                        .overlay {
                            NetworkImage(url: imageURL)
                        }
                        .clipped()
                } else {
                    ZStack {
                        LinearGradient(
                            colors: [.indigo.opacity(0.6), .indigo.opacity(0.3)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                        if let first = article.domain.first {
                            Text(String(first).uppercased())
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
            }
            .frame(width: family == .systemSmall ? 44 : 52, height: family == .systemSmall ? 44 : 52)
            .clipShape(RoundedRectangle(cornerRadius: family == .systemSmall ? 8 : 10, style: .continuous))

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(article.title)
                    .font(.system(size: family == .systemSmall ? 12 : 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    if let status = article.statusLabel {
                        Text(status)
                            .foregroundStyle(.secondary)
                    }
                    if article.statusLabel != nil {
                        Text("·").foregroundStyle(.tertiary)
                    }
                    Text(article.domain)
                        .foregroundStyle(.tertiary)
                    Text("·").foregroundStyle(.tertiary)
                    Text(article.timeAgo)
                        .foregroundStyle(.tertiary)
                }
                .font(.system(size: family == .systemSmall ? 10 : 12))
                .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Network Image for Widgets

struct NetworkImage: View {
    let url: URL
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.clear
            }
        }
        .task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                self.image = UIImage(data: data)
            } catch {}
        }
    }
}

// MARK: - Widget Configuration

struct ReadlingListWidget: Widget {
    let kind: String = "ReadlingListWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 26, *) {
                ReadlingListWidgetEntryView(entry: entry)
                    .containerBackground(.ultraThinMaterial, for: .widget)
            } else {
                ReadlingListWidgetEntryView(entry: entry)
                    .containerBackground(.ultraThinMaterial, for: .widget)
            }
        }
        .configurationDisplayName("Procrastinate Next")
        .description("Your recently saved articles.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemMedium) {
    ReadlingListWidget()
} timeline: {
    ReadingEntry(date: .now, articles: [
        WidgetArticle(title: "The Case for an Ultralight Mac That Does Less", domain: "512pixels.net", timeAgo: "2h ago", imageURL: nil, statusLabel: "To Read"),
        WidgetArticle(title: "AI-Washing Layoffs + Why LLMs Can't Write Well", domain: "podcasts.apple.com", timeAgo: "5h ago", imageURL: nil, statusLabel: "To Do"),
    ])
}

#Preview(as: .systemSmall) {
    ReadlingListWidget()
} timeline: {
    ReadingEntry(date: .now, articles: [
        WidgetArticle(title: "The Case for an Ultralight Mac", domain: "512pixels.net", timeAgo: "2h ago", imageURL: nil, statusLabel: "To Read"),
    ])
}
