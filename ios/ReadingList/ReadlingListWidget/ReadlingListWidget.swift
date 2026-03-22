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
    let toReadCount: Int
    let toDoCount: Int
    let doneCount: Int
    let recentTitles: [String]
}

// MARK: - Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> ReadingEntry {
        ReadingEntry(date: .now, totalCount: 24, toReadCount: 12, toDoCount: 6, doneCount: 6, recentTitles: ["Loading..."])
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
            return ReadingEntry(date: .now, totalCount: 0, toReadCount: 0, toDoCount: 0, doneCount: 0, recentTitles: [])
        }

        comps.queryItems = [
            URLQueryItem(name: "select", value: "title,domain,status,image,saved_at"),
            URLQueryItem(name: "order", value: "saved_at.desc"),
            URLQueryItem(name: "private", value: "eq.false")
        ]

        guard let url = comps.url else {
            return ReadingEntry(date: .now, totalCount: 0, toReadCount: 0, toDoCount: 0, doneCount: 0, recentTitles: [])
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
            return ReadingEntry(
                date: .now,
                totalCount: links.count,
                toReadCount: links.filter { $0.status == "to-read" }.count,
                toDoCount: links.filter { $0.status == "to-try" }.count,
                doneCount: links.filter { $0.status == "done" }.count,
                recentTitles: Array(links.prefix(3).compactMap(\.title))
            )
        } catch {
            return ReadingEntry(date: .now, totalCount: 0, toReadCount: 0, toDoCount: 0, doneCount: 0, recentTitles: [])
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

    // MARK: - Small Widget (stylized)

    var smallWidget: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [Color(red: 0.31, green: 0.27, blue: 0.90), Color(red: 0.20, green: 0.16, blue: 0.70)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 0) {
                // App name
                Text("Procrastinate")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white.opacity(0.6))
                    .textCase(.uppercase)
                    .tracking(1)

                Spacer()

                // Big number
                Text("\(entry.toReadCount)")
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("to read")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()

                // Bottom stats
                HStack(spacing: 8) {
                    miniStat("\(entry.toDoCount)", label: "do", color: .orange)
                    miniStat("\(entry.doneCount)", label: "done", color: .green)
                }
            }
            .padding(2)
        }
    }

    func miniStat(_ value: String, label: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Medium Widget (stylized)

    var mediumWidget: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.31, green: 0.27, blue: 0.90), Color(red: 0.20, green: 0.16, blue: 0.70)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HStack(spacing: 16) {
                // Left: stats
                VStack(alignment: .leading, spacing: 4) {
                    Text("Procrastinate")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white.opacity(0.6))
                        .textCase(.uppercase)
                        .tracking(1)

                    Spacer()

                    Text("\(entry.toReadCount)")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("to read")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))

                    Spacer()

                    HStack(spacing: 10) {
                        miniStat("\(entry.toDoCount)", label: "to do", color: .orange)
                        miniStat("\(entry.doneCount)", label: "done", color: .green)
                    }
                }

                // Divider
                Rectangle()
                    .fill(.white.opacity(0.15))
                    .frame(width: 1)
                    .padding(.vertical, 8)

                // Right: recent articles
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white.opacity(0.5))
                        .textCase(.uppercase)

                    ForEach(entry.recentTitles.prefix(3), id: \.self) { title in
                        Text(title)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(2)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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
        .description("Your reading list at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    ReadlingListWidget()
} timeline: {
    ReadingEntry(date: .now, totalCount: 27, toReadCount: 14, toDoCount: 5, doneCount: 8, recentTitles: [])
}

#Preview(as: .systemMedium) {
    ReadlingListWidget()
} timeline: {
    ReadingEntry(date: .now, totalCount: 27, toReadCount: 14, toDoCount: 5, doneCount: 8, recentTitles: ["The Case for Ultralight Mac", "AI-Washing Layoffs", "Design Systems Guide"])
}
