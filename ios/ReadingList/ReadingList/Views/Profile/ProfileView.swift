import SwiftUI
import Charts

struct ProfileView: View {
    @Environment(LibraryViewModel.self) private var vm
    @Environment(AuthViewModel.self) private var authVM

    @AppStorage("libraryViewMode") private var viewMode: String = "cards"
    @AppStorage("readerFontSize") private var fontSize: Double = 17
    @AppStorage("readerFont") private var fontRaw: String = "system"
    @AppStorage("readerTheme") private var themeRaw: String = "dark"
    @AppStorage("dailyDigestEnabled") private var digestEnabled: Bool = false
    @AppStorage("digestHour") private var digestHour: Int = 8
    @AppStorage("digestMinute") private var digestMinute: Int = 0
    @AppStorage("digestFrequency") private var digestFrequencyRaw: String = DigestFrequency.daily.rawValue

    var body: some View {
        NavigationStack {
            List {
                overviewSection
                statusBreakdownSection
                categoryBreakdownSection
                topDomainsSection
                weeklyActivitySection
                notificationSection
                readerSection
                librarySection
                accountSection
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Overview

    var overviewSection: some View {
        Section {
            HStack(spacing: 0) {
                statBox(value: "\(toReadCount)", label: "To Read", color: .blue)
                statBox(value: "\(toDoCount)", label: "To Do", color: .orange)
                statBox(value: "\(doneCount)", label: "Done", color: .green)
                statBox(value: "\(unsortedCount)", label: "Unsorted", color: .secondary)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    func statBox(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: - Status Breakdown

    var statusBreakdownSection: some View {
        Section("Status Breakdown") {
            let data = statusData
            if !data.isEmpty {
                Chart(data, id: \.status) { item in
                    BarMark(
                        x: .value("Count", item.count),
                        y: .value("Status", item.label)
                    )
                    .foregroundStyle(item.color)
                    .cornerRadius(4)
                }
                .frame(height: CGFloat(data.count) * 36)
                .chartXAxis(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
    }

    struct StatusItem {
        let status: String
        let label: String
        let count: Int
        let color: Color
    }

    var statusData: [StatusItem] {
        let statuses: [(String, String, Color)] = [
            ("to-read", "To Read", .blue),
            ("to-try", "To Do", .orange),
            ("done", "Done", .green),
        ]
        return statuses.compactMap { (status, label, color) in
            let count = vm.allLinks.filter { $0.status == status }.count
            return count > 0 ? StatusItem(status: status, label: label, count: count, color: color) : nil
        }
    }

    // MARK: - Category Breakdown

    var categoryBreakdownSection: some View {
        Section("Top Categories") {
            let cats = categoryData.prefix(6)
            ForEach(Array(cats.enumerated()), id: \.offset) { _, item in
                HStack {
                    Text(item.name)
                    Spacer()
                    Text("\(item.count)")
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    ProgressView(value: Double(item.count), total: Double(categoryData.first?.count ?? 1))
                        .frame(width: 60)
                        .tint(.indigo)
                }
            }
        }
    }

    struct CategoryCount {
        let name: String
        let count: Int
    }

    var categoryData: [CategoryCount] {
        var counts: [String: Int] = [:]
        for link in vm.allLinks {
            if let cat = link.category, !cat.isEmpty {
                counts[cat, default: 0] += 1
            }
        }
        return counts.map { CategoryCount(name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    // MARK: - Top Domains

    var topDomainsSection: some View {
        Section("Top Sources") {
            let domains = domainData.prefix(5)
            ForEach(Array(domains.enumerated()), id: \.offset) { _, item in
                HStack {
                    Text(item.name)
                        .font(.subheadline)
                    Spacer()
                    Text("\(item.count)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    var domainData: [CategoryCount] {
        var counts: [String: Int] = [:]
        for link in vm.allLinks {
            if let dom = link.domain, !dom.isEmpty {
                counts[dom, default: 0] += 1
            }
        }
        return counts.map { CategoryCount(name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    // MARK: - Weekly Activity

    var weeklyActivitySection: some View {
        Section("Last 7 Days") {
            let data = weeklyData
            if data.contains(where: { $0.count > 0 }) {
                Chart(data, id: \.day) { item in
                    BarMark(
                        x: .value("Day", item.label),
                        y: .value("Articles", item.count)
                    )
                    .foregroundStyle(.blue.gradient)
                    .cornerRadius(4)
                }
                .frame(height: 120)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            } else {
                Text("No articles saved this week")
                    .foregroundStyle(.secondary)
            }
        }
    }

    struct DayCount: Identifiable {
        let id = UUID()
        let day: Date
        let label: String
        let count: Int
    }

    var weeklyData: [DayCount] {
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
            return DayCount(day: date, label: formatter.string(from: date), count: count)
        }
    }

    // MARK: - Notifications

    private var digestFrequency: DigestFrequency {
        DigestFrequency(rawValue: digestFrequencyRaw) ?? .daily
    }

    private var digestTime: Date {
        get {
            var comps = DateComponents()
            comps.hour = digestHour
            comps.minute = digestMinute
            return Calendar.current.date(from: comps) ?? Date()
        }
        set {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            digestHour = comps.hour ?? 8
            digestMinute = comps.minute ?? 0
        }
    }

    var notificationSection: some View {
        Section("Digest Notification") {
            Toggle("Enable", isOn: $digestEnabled)
                .onChange(of: digestEnabled) { _, enabled in
                    if enabled {
                        rescheduleDigest()
                    } else {
                        DigestNotificationManager.shared.cancel()
                    }
                }

            if digestEnabled {
                DatePicker("Time", selection: Binding(
                    get: { digestTime },
                    set: { newValue in
                        let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                        digestHour = comps.hour ?? 8
                        digestMinute = comps.minute ?? 0
                        rescheduleDigest()
                    }
                ), displayedComponents: .hourAndMinute)

                Picker("Frequency", selection: Binding(
                    get: { digestFrequencyRaw },
                    set: { newValue in
                        digestFrequencyRaw = newValue
                        rescheduleDigest()
                    }
                )) {
                    ForEach(DigestFrequency.allCases, id: \.rawValue) { freq in
                        Text(freq.label).tag(freq.rawValue)
                    }
                }
            }
        }
    }

    func rescheduleDigest() {
        DigestNotificationManager.shared.requestAndSchedule(
            links: vm.allLinks,
            hour: digestHour,
            minute: digestMinute,
            frequency: digestFrequency
        )
    }

    // MARK: - Reader Settings

    var readerSection: some View {
        Section("Reader") {
            HStack {
                Text("Font Size")
                Spacer()
                Text("\(Int(fontSize))pt")
                    .foregroundStyle(.secondary)
                Stepper("", value: $fontSize, in: 13...24, step: 1)
                    .labelsHidden()
                    .frame(width: 100)
            }
            Picker("Font", selection: $fontRaw) {
                Text("System").tag("system")
                Text("Serif").tag("serif")
                Text("Mono").tag("mono")
            }
            Picker("Theme", selection: $themeRaw) {
                Text("Dark").tag("dark")
                Text("Light").tag("light")
                Text("Sepia").tag("sepia")
            }
        }
    }

    // MARK: - Library Settings

    var librarySection: some View {
        Section("Library") {
            Picker("Default View", selection: $viewMode) {
                Text("Cards").tag("cards")
                Text("List").tag("list")
            }
        }
    }

    // MARK: - Account

    var accountSection: some View {
        Section {
            Button(role: .destructive) {
                authVM.signOut()
            } label: {
                HStack {
                    Spacer()
                    Text("Sign Out")
                    Spacer()
                }
            }
        }
    }

    // MARK: - Computed

    var doneCount: Int { vm.allLinks.filter { $0.status == "done" }.count }
    var toReadCount: Int { vm.allLinks.filter { $0.status == "to-read" }.count }
    var toDoCount: Int { vm.allLinks.filter { $0.status == "to-try" }.count }
    var unsortedCount: Int { vm.allLinks.filter { $0.status == nil || ($0.status != "to-read" && $0.status != "to-try" && $0.status != "done") }.count }

    var averageRating: String {
        let rated = vm.allLinks.compactMap(\.stars).filter { $0 > 0 }
        guard !rated.isEmpty else { return "—" }
        let avg = Double(rated.reduce(0, +)) / Double(rated.count)
        return String(format: "%.1f", avg)
    }
}
