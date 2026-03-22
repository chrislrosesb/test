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
    let recentArticles: [RecentArticle]
    let totalCount: Int
}

struct RecentArticle: Identifiable {
    let id = UUID()
    let title: String
    let domain: String
    let timeAgo: String
    let statusColor: Color?
}

// MARK: - Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> ReadingEntry {
        ReadingEntry(date: .now, recentArticles: [
            RecentArticle(title: "Loading...", domain: "example.com", timeAgo: "now", statusColor: .blue),
            RecentArticle(title: "Loading...", domain: "example.com", timeAgo: "1h", statusColor: nil),
        ], totalCount: 12)
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
            return ReadingEntry(date: .now, recentArticles: [], totalCount: 0)
        }

        comps.queryItems = [
            URLQueryItem(name: "select", value: "title,domain,status,saved_at"),
            URLQueryItem(name: "order", value: "saved_at.desc"),
            URLQueryItem(name: "limit", value: "5"),
            URLQueryItem(name: "private", value: "eq.false")
        ]

        guard let url = comps.url else {
            return ReadingEntry(date: .now, recentArticles: [], totalCount: 0)
        }

        var req = URLRequest(url: url)
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        if let token = UserDefaults.standard.string(forKey: "supabase_access_token") {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        // Get total count via a second lightweight request
        req.setValue("true", forHTTPHeaderField: "Prefer")

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
                RecentArticle(
                    title: link.title ?? "Untitled",
                    domain: link.domain ?? "",
                    timeAgo: timeAgo(from: link.savedAt),
                    statusColor: statusColor(for: link.status)
                )
            }
            return ReadingEntry(date: .now, recentArticles: articles, totalCount: links.count)
        } catch {
            return ReadingEntry(date: .now, recentArticles: [], totalCount: 0)
        }
    }

    func timeAgo(from date: Date?) -> String {
        guard let date else { return "" }
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "now" }
        if interval < 3600 { return "\(Int(interval / 60))m" }
        if interval < 86400 { return "\(Int(interval / 3600))h" }
        if interval < 604800 { return "\(Int(interval / 86400))d" }
        return "\(Int(interval / 604800))w"
    }

    func statusColor(for status: String?) -> Color? {
        switch status {
        case "to-read": return .blue
        case "to-try": return .orange
        case "done": return .green
        default: return nil
        }
    }
}

// MARK: - Widget Views

struct ReadlingListWidgetEntryView: View {
    var entry: ReadingEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        default:
            smallWidget
        }
    }

    // MARK: - Small: Last 2 saves

    var smallWidget: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.31, green: 0.27, blue: 0.90), Color(red: 0.20, green: 0.16, blue: 0.70)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "books.vertical.fill")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    Text("RECENT")
                        .font(.caption2)
                        .fontWeight(.heavy)
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(1)
                    Spacer()
                }

                Spacer()

                ForEach(entry.recentArticles.prefix(2)) { article in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(article.title)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        HStack(spacing: 4) {
                            if let color = article.statusColor {
                                Circle().fill(color).frame(width: 6, height: 6)
                            }
                            Text(article.domain)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.5))
                            Text("·").foregroundStyle(.white.opacity(0.3))
                            Text(article.timeAgo)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(2)
        }
    }

    // MARK: - Medium: Last 3 saves with more detail

    var mediumWidget: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.31, green: 0.27, blue: 0.90), Color(red: 0.20, green: 0.16, blue: 0.70)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: "books.vertical.fill")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    Text("RECENTLY SAVED")
                        .font(.caption2)
                        .fontWeight(.heavy)
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(1)
                    Spacer()
                }

                Spacer(minLength: 6)

                ForEach(entry.recentArticles.prefix(3)) { article in
                    HStack(spacing: 10) {
                        // Status dot
                        if let color = article.statusColor {
                            Circle().fill(color).frame(width: 8, height: 8)
                        } else {
                            Circle().fill(.white.opacity(0.2)).frame(width: 8, height: 8)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text(article.title)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text("\(article.domain) · \(article.timeAgo)")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.45))
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)

                    if article.id != entry.recentArticles.prefix(3).last?.id {
                        Rectangle()
                            .fill(.white.opacity(0.08))
                            .frame(height: 1)
                            .padding(.leading, 18)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(2)
        }
    }
}

// MARK: - Widget Configuration

struct ReadlingListWidget: Widget {
    let kind: String = "ReadlingListWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ReadlingListWidgetEntryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Procrastinate")
        .description("Your recently saved articles.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    ReadlingListWidget()
} timeline: {
    ReadingEntry(date: .now, recentArticles: [
        RecentArticle(title: "The Case for an Ultralight Mac", domain: "512pixels.net", timeAgo: "2h", statusColor: .blue),
        RecentArticle(title: "AI-Washing Layoffs + Why LLMs Can't Write", domain: "podcasts.apple.com", timeAgo: "5h", statusColor: .orange),
    ], totalCount: 27)
}

#Preview(as: .systemMedium) {
    ReadlingListWidget()
} timeline: {
    ReadingEntry(date: .now, recentArticles: [
        RecentArticle(title: "The Case for an Ultralight Mac", domain: "512pixels.net", timeAgo: "2h", statusColor: .blue),
        RecentArticle(title: "AI-Washing Layoffs + Why LLMs Can't Write", domain: "podcasts.apple.com", timeAgo: "5h", statusColor: .orange),
        RecentArticle(title: "Gemini Task Automation Is Impressive", domain: "theverge.com", timeAgo: "1d", statusColor: nil),
    ], totalCount: 27)
}
