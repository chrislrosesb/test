import UserNotifications

enum DigestFrequency: String, CaseIterable {
    case daily = "daily"
    case weekdays = "weekdays"
    case weekly = "weekly"

    var label: String {
        switch self {
        case .daily: return "Every Day"
        case .weekdays: return "Weekdays"
        case .weekly: return "Weekly (Mon)"
        }
    }
}

final class DigestNotificationManager {
    static let shared = DigestNotificationManager()
    private init() {}

    private let notificationPrefix = "daily-digest"

    func requestAndSchedule(links: [Link], hour: Int, minute: Int, frequency: DigestFrequency) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            self.schedule(links: links, hour: hour, minute: minute, frequency: frequency)
        }
    }

    func schedule(links: [Link], hour: Int, minute: Int, frequency: DigestFrequency) {
        let center = UNUserNotificationCenter.current()
        // Remove all existing digest notifications
        center.removePendingNotificationRequests(withIdentifiers: identifiers(for: frequency))

        let content = buildContent(links: links)

        switch frequency {
        case .daily:
            // One notification, repeats daily
            var dc = DateComponents()
            dc.hour = hour
            dc.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
            let request = UNNotificationRequest(identifier: "\(notificationPrefix)-daily", content: content, trigger: trigger)
            center.add(request)

        case .weekdays:
            // One notification per weekday (Mon-Fri = 2-6)
            for weekday in 2...6 {
                var dc = DateComponents()
                dc.hour = hour
                dc.minute = minute
                dc.weekday = weekday
                let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
                let request = UNNotificationRequest(identifier: "\(notificationPrefix)-wd\(weekday)", content: content, trigger: trigger)
                center.add(request)
            }

        case .weekly:
            // Monday only (weekday 2)
            var dc = DateComponents()
            dc.hour = hour
            dc.minute = minute
            dc.weekday = 2
            let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
            let request = UNNotificationRequest(identifier: "\(notificationPrefix)-weekly", content: content, trigger: trigger)
            center.add(request)
        }
    }

    func cancel() {
        let center = UNUserNotificationCenter.current()
        // Remove all possible digest IDs
        let allIDs = ["\(notificationPrefix)-daily", "\(notificationPrefix)-weekly"]
            + (2...6).map { "\(notificationPrefix)-wd\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: allIDs)
    }

    private func identifiers(for frequency: DigestFrequency) -> [String] {
        switch frequency {
        case .daily: return ["\(notificationPrefix)-daily"]
        case .weekdays: return (2...6).map { "\(notificationPrefix)-wd\($0)" }
        case .weekly: return ["\(notificationPrefix)-weekly"]
        }
    }

    private func buildContent(links: [Link]) -> UNMutableNotificationContent {
        let toReadCount = links.filter { $0.status == "to-read" }.count
        let toDoCount = links.filter { $0.status == "to-try" }.count
        let unsorted = links.filter { $0.status == nil || ($0.status != "to-read" && $0.status != "to-try" && $0.status != "done") }.count

        var catCounts: [String: Int] = [:]
        for link in links where link.status != "done" {
            if let cat = link.category, !cat.isEmpty {
                catCounts[cat, default: 0] += 1
            }
        }
        let topCategory = catCounts.max(by: { $0.value < $1.value })?.key

        let content = UNMutableNotificationContent()
        content.title = "Reading List"

        var parts: [String] = []
        if toReadCount > 0 { parts.append("\(toReadCount) to read") }
        if toDoCount > 0 { parts.append("\(toDoCount) to do") }
        if unsorted > 0 { parts.append("\(unsorted) unsorted") }

        var body = parts.joined(separator: " · ")
        if let cat = topCategory, let count = catCounts[cat] {
            body += ". \(count) about \(cat)."
        }
        content.body = body.isEmpty ? "Check your reading list!" : body
        content.sound = .default

        return content
    }
}
