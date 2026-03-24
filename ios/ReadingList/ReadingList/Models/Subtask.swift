import Foundation

struct Subtask: Codable, Identifiable, Hashable {
    var id: String
    var linkId: String
    var text: String
    var isDone: Bool
    var createdAt: Date

    init(id: String = UUID().uuidString, linkId: String = "", text: String, isDone: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.linkId = linkId
        self.text = text
        self.isDone = isDone
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, text
        case linkId = "link_id"
        case isDone = "is_done"
        case createdAt = "created_at"
    }
}

// MARK: - Store (Supabase-backed)

@Observable
@MainActor
final class SubtaskStore {
    static let shared = SubtaskStore()

    private(set) var storage: [String: [Subtask]] = [:]

    private let baseURL = "https://ownqyyfgferczpdgihgr.supabase.co"
    private let apiKey = "sb_publishable_RPJSQlVO4isbKnZve8NlWg_55EO350Y"

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        let frac = ISO8601DateFormatter()
        frac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        d.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let s = try c.decode(String.self)
            if let date = frac.date(from: s) { return date }
            if let date = plain.date(from: s) { return date }
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Cannot parse date: \(s)")
        }
        return d
    }()

    private init() {}

    // MARK: - Read

    func loadAll() async {
        do {
            var comps = URLComponents(string: "\(baseURL)/rest/v1/subtasks")!
            comps.queryItems = [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "order", value: "created_at.asc")
            ]
            var req = URLRequest(url: comps.url!)
            req.setValue(apiKey, forHTTPHeaderField: "apikey")
            req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

            let (data, _) = try await URLSession.shared.data(for: req)
            let all = try decoder.decode([Subtask].self, from: data)

            var grouped: [String: [Subtask]] = [:]
            for subtask in all {
                grouped[subtask.linkId, default: []].append(subtask)
            }
            storage = grouped
        } catch {
            print("❌ SubtaskStore.loadAll failed: \(error)")
        }
    }

    func subtasks(for linkId: String) -> [Subtask] {
        storage[linkId] ?? []
    }

    // MARK: - Write

    func add(text: String, to linkId: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let subtask = Subtask(linkId: linkId, text: trimmed)

        // Optimistic local update
        storage[linkId, default: []].append(subtask)

        Task {
            do {
                let url = URL(string: "\(baseURL)/rest/v1/subtasks")!
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.setValue(apiKey, forHTTPHeaderField: "apikey")
                req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

                let body: [String: Any] = [
                    "id": subtask.id,
                    "link_id": linkId,
                    "text": trimmed,
                    "is_done": false
                ]
                req.httpBody = try JSONSerialization.data(withJSONObject: body)

                let (_, response) = try await URLSession.shared.data(for: req)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                if !(200...299).contains(status) {
                    print("❌ SubtaskStore.add failed with status \(status)")
                }
            } catch {
                print("❌ SubtaskStore.add failed: \(error)")
            }
        }
    }

    func toggle(id: String, in linkId: String) {
        guard var tasks = storage[linkId],
              let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[idx].isDone.toggle()
        let newValue = tasks[idx].isDone
        storage[linkId] = tasks

        Task {
            do {
                try await patch(id: id, fields: ["is_done": newValue])
            } catch {
                print("❌ SubtaskStore.toggle failed: \(error)")
            }
        }
    }

    func delete(id: String, from linkId: String) {
        storage[linkId]?.removeAll { $0.id == id }
        if storage[linkId]?.isEmpty == true { storage.removeValue(forKey: linkId) }

        Task {
            do {
                try await remove(id: id)
            } catch {
                print("❌ SubtaskStore.delete failed: \(error)")
            }
        }
    }

    func update(_ tasks: [Subtask], for linkId: String) {
        if tasks.isEmpty { storage.removeValue(forKey: linkId) }
        else { storage[linkId] = tasks }
    }

    // MARK: - Network helpers

    private func patch(id: String, fields: [String: Any]) async throws {
        var comps = URLComponents(string: "\(baseURL)/rest/v1/subtasks")!
        comps.queryItems = [URLQueryItem(name: "id", value: "eq.\(id)")]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: fields)
        let (_, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if !(200...299).contains(status) {
            print("❌ SubtaskStore.patch failed with status \(status)")
        }
    }

    private func remove(id: String) async throws {
        var comps = URLComponents(string: "\(baseURL)/rest/v1/subtasks")!
        comps.queryItems = [URLQueryItem(name: "id", value: "eq.\(id)")]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "DELETE"
        req.setValue(apiKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if !(200...299).contains(status) {
            print("❌ SubtaskStore.remove failed with status \(status)")
        }
    }
}
