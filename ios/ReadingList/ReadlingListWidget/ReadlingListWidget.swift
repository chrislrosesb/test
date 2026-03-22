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
    let totalCount: Int
    let unreadCount: Int
    let toReadCount: Int
    let doneCount: Int
    let recentTitles: [String]  // Last 3 article titles
}

// MARK: - Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> ReadingEntry {
        ReadingEntry(date: .now, totalCount: 24, unreadCount: 12, toReadCount: 8, doneCount: 6, recentTitles: ["Loading...", "Loading...", "Loading..."])
    }

    func getSnapshot(in context: Context, completion: @escaping (ReadingEntry) -> ()) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReadingEntry>) -> ()) {
        Task {
            let entry = await fetchEntry()
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    func fetchEntry() async -> ReadingEntry {
        let baseURL = "https://ownqyyfgferczpdgihgr.supabase.co"
        let anonKey = "sb_publishable_RPJSQlVO4isbKnZve8NlWg_55EO350Y"

        guard var comps = URLComponents(string: "\(baseURL)/rest/v1/links") else {
            return ReadingEntry(date: .now, totalCount: 0, unreadCount: 0, toReadCount: 0, doneCount: 0, recentTitles: [])
        }

        comps.queryItems = [
            URLQueryItem(name: "select", value: "title,domain,status,image,saved_at"),
            URLQueryItem(name: "order", value: "saved_at.desc"),
            URLQueryItem(name: "private", value: "eq.false")
        ]

        guard let url = comps.url else {
            return ReadingEntry(date: .now, totalCount: 0, unreadCount: 0, toReadCount: 0, doneCount: 0, recentTitles: [])
        }

        var req = URLRequest(url: url)
        req.setValue(anonKey, forHTTPHeaderField: "apikey")

        // Try to use stored auth token
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
            let total = links.count
            let unread = links.filter { $0.status != "done" }.count
            let toRead = links.filter { $0.status == "to-read" }.count
            let done = links.filter { $0.status == "done" }.count
            let recent = Array(links.prefix(3).compactMap(\.title))

            return ReadingEntry(date: .now, totalCount: total, unreadCount: unread, toReadCount: toRead, doneCount: done, recentTitles: recent)
        } catch {
            return ReadingEntry(date: .now, totalCount: 0, unreadCount: 0, toReadCount: 0, doneCount: 0, recentTitles: [])
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

    var smallWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "books.vertical.fill")
                    .foregroundStyle(.indigo)
                Text("Reading List")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            Text("\(entry.unreadCount)")
                .font(.system(size: 36, weight: .bold, design: .rounded))

            Text("unread")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 12) {
                Label("\(entry.toReadCount)", systemImage: "book")
                    .font(.caption2)
                    .foregroundStyle(.blue)
                Label("\(entry.doneCount)", systemImage: "checkmark")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var mediumWidget: some View {
        HStack(spacing: 16) {
            // Left: stats
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "books.vertical.fill")
                        .foregroundStyle(.indigo)
                    Text("Reading List")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }

                Text("\(entry.unreadCount) unread")
                    .font(.title2)
                    .fontWeight(.bold)

                HStack(spacing: 10) {
                    Label("\(entry.toReadCount) to read", systemImage: "book")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Label("\(entry.doneCount) done", systemImage: "checkmark")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                Spacer()

                Text("\(entry.totalCount) total")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Divider()

            // Right: recent articles
            VStack(alignment: .leading, spacing: 6) {
                Text("Recent")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                ForEach(entry.recentTitles.prefix(3), id: \.self) { title in
                    Text(title)
                        .font(.caption)
                        .lineLimit(2)
                }

                Spacer()
            }
        }
    }
}

// MARK: - Widget Configuration

struct ReadlingListWidget: Widget {
    let kind: String = "ReadlingListWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                ReadlingListWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                ReadlingListWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Reading List")
        .description("Unread count and recent saves.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    ReadlingListWidget()
} timeline: {
    ReadingEntry(date: .now, totalCount: 24, unreadCount: 12, toReadCount: 8, doneCount: 6, recentTitles: ["The Case for AI", "SwiftUI Tips", "Design Systems"])
}

#Preview(as: .systemMedium) {
    ReadlingListWidget()
} timeline: {
    ReadingEntry(date: .now, totalCount: 24, unreadCount: 12, toReadCount: 8, doneCount: 6, recentTitles: ["The Case for AI", "SwiftUI Tips", "Design Systems"])
}
