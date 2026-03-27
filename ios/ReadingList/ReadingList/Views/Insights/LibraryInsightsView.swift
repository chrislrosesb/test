import SwiftUI
import Charts
#if canImport(FoundationModels)
import FoundationModels
#endif

private enum InsightsPhase {
    case idle
    case generating
    case ready(narrative: String, actionItems: [String], generatedAt: Date)
    case unavailable(String)
    case error(String)
}

// MARK: - Data models

private struct StatusItem: Identifiable {
    var id: String { label }
    let label: String
    let count: Int
    let color: Color
}

private struct NameCount: Identifiable {
    var id: String { name }
    let name: String
    let count: Int
}

private struct DayCount: Identifiable {
    var id: Date { date }
    let date: Date
    let label: String
    let count: Int
}

private struct MonthCount: Identifiable {
    var id: Date { date }
    let date: Date
    let label: String
    let count: Int
}

private struct RatingRow: Identifiable {
    var id: Int { stars }
    let stars: Int
    let count: Int
    let label: String
}

// MARK: - Main View

struct LibraryInsightsView: View {
    @Environment(LibraryViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var phase: InsightsPhase = .idle
    @State private var appeared = false
    @State private var animProgress: Double = 0
    @State private var fullTextCount: Int = 0
    @State private var fullTextWordCount: Int = 0

    // MARK: - Derived data

    private var totalCount: Int { vm.allLinks.count }

    private var toReadCount: Int  { vm.allLinks.filter { $0.status == "to-read" }.count }
    private var toDoCount: Int    { vm.allLinks.filter { $0.status == "to-try" }.count }
    private var doneCount: Int    { vm.allLinks.filter { $0.status == "done" }.count }
    private var unsortedCount: Int { totalCount - toReadCount - toDoCount - doneCount }

    private var statusData: [StatusItem] {
        [
            StatusItem(label: "To Read",  count: toReadCount,   color: .blue),
            StatusItem(label: "To Do",    count: toDoCount,     color: .orange),
            StatusItem(label: "Done",     count: doneCount,     color: .green),
            StatusItem(label: "Unsorted", count: unsortedCount, color: Color(UIColor.systemGray3)),
        ].filter { $0.count > 0 }
    }

    private var categoryData: [NameCount] {
        var counts: [String: Int] = [:]
        for link in vm.allLinks { if let c = link.category, !c.isEmpty { counts[c, default: 0] += 1 } }
        return counts.map { NameCount(name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
            .prefix(8).map { $0 }
    }

    private var domainData: [NameCount] {
        var counts: [String: Int] = [:]
        for link in vm.allLinks { if let d = link.domain, !d.isEmpty { counts[d, default: 0] += 1 } }
        return counts.map { NameCount(name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
            .prefix(6).map { $0 }
    }

    private var topTags: [(tag: String, count: Int)] {
        Array(vm.tagCounts.prefix(10))
    }

    private var weeklyData: [DayCount] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return (0..<7).reversed().map { daysAgo in
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            let count = vm.allLinks.filter { link in
                guard let saved = link.savedAt else { return false }
                return calendar.isDate(saved, inSameDayAs: date)
            }.count
            return DayCount(date: date, label: formatter.string(from: date), count: count)
        }
    }

    private var monthlyData: [MonthCount] {
        let calendar = Calendar.current
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return (0..<6).reversed().map { monthsAgo in
            let date = calendar.date(byAdding: .month, value: -monthsAgo, to: now)!
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
            let end = calendar.date(byAdding: .month, value: 1, to: start)!
            let count = vm.allLinks.filter { link in
                guard let saved = link.savedAt else { return false }
                return saved >= start && saved < end
            }.count
            return MonthCount(date: start, label: formatter.string(from: date), count: count)
        }
    }

    private var ratingData: [RatingRow] {
        (1...5).reversed().map { stars in
            let count = vm.allLinks.filter { ($0.stars ?? 0) == stars }.count
            return RatingRow(stars: stars, count: count, label: String(repeating: "★", count: stars))
        }
    }

    private var libraryAgeWeeks: Double {
        guard let oldest = vm.allLinks.compactMap(\.savedAt).min() else { return 1 }
        let days = Calendar.current.dateComponents([.day], from: oldest, to: Date()).day ?? 1
        return max(1, Double(days) / 7)
    }

    private var allTimeVelocity: Double {
        guard libraryAgeWeeks > 0 else { return 0 }
        return Double(totalCount) / libraryAgeWeeks
    }

    private var rollingVelocity: Double {
        let cutoff = Calendar.current.date(byAdding: .day, value: -28, to: Date()) ?? Date()
        let recent = vm.allLinks.filter { ($0.savedAt ?? .distantPast) >= cutoff }.count
        return Double(recent) / 4.0
    }

    private var libraryAgeLabel: String {
        guard let oldest = vm.allLinks.compactMap(\.savedAt).min() else { return "new" }
        let days = Calendar.current.dateComponents([.day], from: oldest, to: Date()).day ?? 0
        if days < 14 { return "\(days)d" }
        if days < 60 { return "\(days / 7)w" }
        return "\(days / 30)mo"
    }

    private var isWide: Bool { sizeClass == .regular }
    private var chartHeight: CGFloat { isWide ? 150 : 110 }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    headerSection
                    statusSection
                    activitySection
                    categoriesSection
                    tagsAndSourcesSection
                    starRatingsSection
                    fullTextSection
                    Divider().padding(.horizontal, 16)
                    aiSection
                    Spacer(minLength: 40)
                }
                .padding(.bottom, 40)
            }
            .background(Color(UIColor.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .task {
                // Use fetch(linkId:) per article — avoids the fetchAll SortDescriptor
                // silent-failure issue; fetch(linkId:) is proven-working in ArticleDetailView.
                var count = 0
                var totalWords = 0
                for link in vm.allLinks {
                    if let ft = ArticleFullTextStore.shared.fetch(linkId: link.id) {
                        count += 1
                        totalWords += ft.wordCount
                    }
                }
                fullTextCount = count
                fullTextWordCount = totalWords
                withAnimation(.easeOut(duration: 0.8)) {
                    appeared = true
                    animProgress = 1.0
                }
            }
        }
    }

    // MARK: - Header

    var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Library Insights")
                .font(.largeTitle)
                .fontWeight(.black)
            HStack(spacing: 10) {
                Label("\(totalCount) articles", systemImage: "books.vertical")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.tertiary)
                Label(libraryAgeLabel, systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if allTimeVelocity > 0 {
                    Text("·")
                        .foregroundStyle(.tertiary)
                    velocityBadge
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animation(.easeOut(duration: 0.5), value: appeared)
    }

    var velocityBadge: some View {
        let trend = rollingVelocity - allTimeVelocity
        let arrow = trend > 0.5 ? "arrow.up" : (trend < -0.5 ? "arrow.down" : "minus")
        let color: Color = trend > 0.5 ? .green : (trend < -0.5 ? .orange : .secondary)
        return HStack(spacing: 3) {
            Image(systemName: arrow)
                .font(.caption2)
            Text(String(format: "%.1f/wk", rollingVelocity))
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.12), in: Capsule())
    }

    // MARK: - Status Section

    var statusSection: some View {
        sectionCard(delay: 0.05) {
            VStack(alignment: .leading, spacing: 16) {
                sectionLabel("Status")
                if isWide {
                    HStack(alignment: .top, spacing: 20) {
                        donutChart
                            .frame(width: 200, height: 200)
                        VStack(alignment: .leading, spacing: 12) {
                            donutLegend
                            statCardsGrid
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    donutChart
                        .frame(height: 180)
                    donutLegend
                    statCardsGrid
                }
            }
        }
    }

    var donutChart: some View {
        ZStack {
            if statusData.isEmpty {
                Circle()
                    .stroke(Color(UIColor.systemGray5), lineWidth: 28)
            } else {
                Chart(statusData) { item in
                    SectorMark(
                        angle: .value("Count", appeared ? item.count : 0),
                        innerRadius: .ratio(0.62),
                        angularInset: 2
                    )
                    .foregroundStyle(item.color)
                    .cornerRadius(4)
                }
                .animation(.easeOut(duration: 0.9), value: appeared)
            }

            VStack(spacing: 2) {
                Text("\(Int(Double(totalCount) * animProgress))")
                    .font(.title)
                    .fontWeight(.black)
                    .monospacedDigit()
                Text("total")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    var donutLegend: some View {
        let total = Double(totalCount)
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(statusData) { item in
                HStack(spacing: 8) {
                    Circle()
                        .fill(item.color)
                        .frame(width: 8, height: 8)
                    Text(item.label)
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(Double(item.count) * animProgress))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                    if total > 0 {
                        Text(String(format: "%.0f%%", Double(item.count) / total * 100))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 32, alignment: .trailing)
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    var statCardsGrid: some View {
        let cols = isWide ? [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())] :
                            [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: cols, spacing: 10) {
            statCard(value: toReadCount, label: "To Read", color: .blue, delay: 0.1)
            statCard(value: toDoCount,   label: "To Do",   color: .orange, delay: 0.15)
            statCard(value: doneCount,   label: "Done",    color: .green, delay: 0.2)
            statCard(value: unsortedCount, label: "Unsorted", color: Color(UIColor.systemGray), delay: 0.25)
        }
    }

    func statCard(value: Int, label: String, color: Color, delay: Double) -> some View {
        VStack(spacing: 4) {
            Text("\(Int(Double(value) * animProgress))")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Activity Section

    var activitySection: some View {
        sectionCard(delay: 0.1) {
            VStack(alignment: .leading, spacing: 20) {
                // 7-day
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("Last 7 Days")
                    let hasActivity = weeklyData.contains { $0.count > 0 }
                    if hasActivity {
                        Chart(weeklyData) { item in
                            BarMark(
                                x: .value("Day", item.label),
                                y: .value("Articles", appeared ? item.count : 0)
                            )
                            .foregroundStyle(Color.indigo.gradient)
                            .cornerRadius(4)
                        }
                        .frame(height: chartHeight)
                        .chartYAxis(.hidden)
                        .animation(.easeOut(duration: 0.7).delay(0.15), value: appeared)
                    } else {
                        Text("No articles saved this week")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                // 6-month
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("Last 6 Months")
                    let hasMonthly = monthlyData.contains { $0.count > 0 }
                    if hasMonthly {
                        Chart(monthlyData) { item in
                            BarMark(
                                x: .value("Month", item.label),
                                y: .value("Articles", appeared ? item.count : 0)
                            )
                            .foregroundStyle(Color.purple.gradient)
                            .cornerRadius(4)
                        }
                        .frame(height: chartHeight)
                        .chartYAxis(.hidden)
                        .animation(.easeOut(duration: 0.7).delay(0.2), value: appeared)
                    } else {
                        Text("Not enough data yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Categories Section

    var categoriesSection: some View {
        sectionCard(delay: 0.15) {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("Top Categories")
                if categoryData.isEmpty {
                    Text("No categories yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Chart(categoryData) { item in
                        BarMark(
                            x: .value("Count", appeared ? item.count : 0),
                            y: .value("Category", item.name)
                        )
                        .foregroundStyle(Color.indigo.gradient)
                        .cornerRadius(4)
                        .annotation(position: .trailing, alignment: .leading) {
                            Text("\(item.count)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .opacity(appeared ? 1 : 0)
                        }
                    }
                    .frame(height: CGFloat(categoryData.count) * (isWide ? 36 : 32))
                    .chartXAxis(.hidden)
                    .animation(.easeOut(duration: 0.7).delay(0.2), value: appeared)
                }
            }
        }
    }

    // MARK: - Tags + Sources Section

    var tagsAndSourcesSection: some View {
        Group {
            if isWide {
                HStack(alignment: .top, spacing: 16) {
                    tagsCard
                    sourcesCard
                }
                .padding(.horizontal, 16)
            } else {
                VStack(spacing: 16) {
                    tagsCard
                    sourcesCard
                }
                .padding(.horizontal, 16)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(.easeOut(duration: 0.5).delay(0.2), value: appeared)
    }

    var tagsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Top Tags")
            if topTags.isEmpty {
                Text("No tags yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                // Flow wrap using a simple line-break approach
                TagFlowLayout(spacing: 6) {
                    ForEach(topTags, id: \.tag) { item in
                        HStack(spacing: 3) {
                            Text(item.tag)
                                .font(.caption)
                                .fontWeight(.medium)
                            Text("·")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text("\(item.count)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.indigo.opacity(0.7))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.indigo.opacity(0.1), in: Capsule())
                        .foregroundStyle(.indigo)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    var sourcesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Top Sources")
            if domainData.isEmpty {
                Text("No sources yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(domainData.enumerated()), id: \.element.id) { i, item in
                        HStack(spacing: 10) {
                            Text("\(i + 1)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .frame(width: 18, height: 18)
                                .background(Color.indigo.opacity(0.7), in: Circle())
                            Text(item.name)
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer()
                            Text("\(item.count)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Star Ratings Section

    var starRatingsSection: some View {
        sectionCard(delay: 0.25) {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("Star Ratings")
                let maxCount = ratingData.map(\.count).max() ?? 1
                VStack(spacing: 10) {
                    ForEach(ratingData) { row in
                        HStack(spacing: 10) {
                            Text(row.label)
                                .font(.subheadline)
                                .foregroundStyle(.yellow)
                                .frame(width: isWide ? 80 : 60, alignment: .leading)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(UIColor.systemGray5))
                                        .frame(height: 10)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.yellow.gradient)
                                        .frame(
                                            width: maxCount > 0
                                                ? geo.size.width * CGFloat(row.count) / CGFloat(maxCount) * (appeared ? 1 : 0)
                                                : 0,
                                            height: 10
                                        )
                                        .animation(.easeOut(duration: 0.7).delay(0.25 + Double(5 - row.stars) * 0.05), value: appeared)
                                }
                            }
                            .frame(height: 10)
                            Text("\(row.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                }

                let unrated = vm.allLinks.filter { ($0.stars ?? 0) == 0 }.count
                if unrated > 0 {
                    Text("\(unrated) unrated")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }
            }
        }
    }

    // MARK: - Full Text Section

    var fullTextSection: some View {
        sectionCard(delay: 0.3) {
            VStack(alignment: .leading, spacing: 16) {
                sectionLabel("Deep Saves")
                HStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .stroke(Color(UIColor.systemGray5), lineWidth: 10)
                        Circle()
                            .trim(from: 0, to: totalCount > 0 ? CGFloat(fullTextCount) / CGFloat(totalCount) * (appeared ? 1 : 0) : 0)
                            .stroke(Color.indigo.gradient, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 0.9).delay(0.3), value: appeared)
                        VStack(spacing: 1) {
                            Text("\(fullTextCount)")
                                .font(.title3)
                                .fontWeight(.black)
                                .monospacedDigit()
                            Text("of \(totalCount)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 90, height: 90)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Full text + AI digest saved on-device")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        if fullTextCount > 0 {
                            let avgWords = fullTextWordCount / fullTextCount
                            Text("~\(avgWords) words per article")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            let estMB = Double(fullTextCount * 5) / 1000.0
                            Text(String(format: "~%.1f MB on device", estMB))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        } else {
                            Text("Save full text from any article's detail view")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - AI Section

    var aiSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What your library says about you")
                .font(.headline)
                .padding(.horizontal, 20)

            aiNarrativeCard
                .padding(.horizontal, 16)

            if case .ready(_, let actionItems, _) = phase, !actionItems.isEmpty {
                actionItemsSection(actionItems)
            }
        }
    }

    @ViewBuilder
    var aiNarrativeCard: some View {
        switch phase {
        case .idle:
            Button {
                Task { await generateInsights() }
            } label: {
                Label("Generate Insights", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)

        case .generating:
            HStack(spacing: 12) {
                ProgressView().scaleEffect(0.9)
                Text("Analysing your library…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

        case .ready(let narrative, _, let generatedAt):
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("AI Analysis", systemImage: "sparkles")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.purple)
                    Spacer()
                    Text(generatedAt, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Button {
                        Task { await generateInsights() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(narrative)
                    .font(.subheadline)
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

        case .unavailable(let msg):
            Label(msg, systemImage: "sparkles.slash")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

        case .error(let msg):
            VStack(alignment: .leading, spacing: 8) {
                Label("Analysis failed", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .fontWeight(.semibold)
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Try Again") { Task { await generateInsights() } }
                    .font(.caption)
                    .tint(.indigo)
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    func actionItemsSection(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Action Items")
                .font(.headline)
                .padding(.horizontal, 20)

            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(i + 1)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.indigo, in: Circle())
                    Text(item)
                        .font(.subheadline)
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Helpers

    func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .fontWeight(.semibold)
    }

    func sectionCard<Content: View>(delay: Double, @ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 16)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 24)
            .animation(.easeOut(duration: 0.55).delay(delay), value: appeared)
    }

    // MARK: - AI Logic

    func generateInsights() async {
        guard !vm.libraryStatsContext.isEmpty, vm.allLinks.count > 0 else {
            phase = .unavailable("Add some articles first.")
            return
        }
        phase = .generating
        if #available(iOS 26, *) {
            await runFoundationModelsInsights()
        } else {
            phase = .unavailable("AI Insights requires iOS 26 and Apple Intelligence.")
        }
    }

    @available(iOS 26, *)
    func runFoundationModelsInsights() async {
        #if canImport(FoundationModels)
        let prompt = """
        Here are statistics about my personal reading list library:

        \(vm.libraryStatsContext)

        Respond with two clearly labelled sections:

        NARRATIVE:
        2-3 paragraphs about what these statistics reveal about my reading habits and interests right now. \
        What am I gravitating toward? What does the tag/category mix suggest about my current focus? \
        Be specific about the numbers, not generic.

        ACTION ITEMS:
        Exactly 3 specific, actionable suggestions based on the data. \
        Format each as a single sentence starting with a verb. \
        Focus on what I should do with my backlog.

        Be direct and personal. Use "you" and reference the actual numbers.
        """
        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            let (narrative, actionItems) = parseInsightsResponse(response.content)
            phase = .ready(narrative: narrative, actionItems: actionItems, generatedAt: Date())
        } catch {
            let desc = error.localizedDescription.lowercased()
            if desc.contains("available") || desc.contains("support") || desc.contains("intelligence") {
                phase = .unavailable("Apple Intelligence is not available on this device.")
            } else {
                phase = .error(error.localizedDescription)
            }
        }
        #else
        phase = .unavailable("FoundationModels framework is not available in this build.")
        #endif
    }

    func parseInsightsResponse(_ raw: String) -> (narrative: String, actionItems: [String]) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let narrativeRange = text.range(of: "NARRATIVE:", options: .caseInsensitive),
              let actionRange   = text.range(of: "ACTION ITEMS:", options: .caseInsensitive) else {
            return (text, [])
        }

        let narrative = String(text[narrativeRange.upperBound..<actionRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let actionBlock = String(text[actionRange.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let actionItems = actionBlock
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { line -> String in
                var result = line
                if let range = result.range(of: #"^(\d+\.\s*|[-•]\s*)"#, options: .regularExpression) {
                    result = String(result[range.upperBound...])
                }
                return result
            }

        return (narrative, actionItems)
    }
}
