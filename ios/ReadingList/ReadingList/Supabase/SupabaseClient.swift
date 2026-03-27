import Foundation

// MARK: - Config

private enum Config {
    static let baseURL = "https://ownqyyfgferczpdgihgr.supabase.co"
    static let anonKey = "sb_publishable_RPJSQlVO4isbKnZve8NlWg_55EO350Y"
}

// MARK: - Errors

enum SupabaseError: LocalizedError {
    case auth(String)
    case fetch
    case decode(String)
    case update

    var errorDescription: String? {
        switch self {
        case .auth(let msg): return msg
        case .fetch: return "Failed to load articles."
        case .decode(let detail): return "Decode error: \(detail)"
        case .update: return "Failed to save changes."
        }
    }
}

// MARK: - Client

final class SupabaseClient {
    static let shared = SupabaseClient()
    private init() {}

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

    // MARK: - Token

    var accessToken: String? {
        get { UserDefaults.standard.string(forKey: "supabase_access_token") }
        set { UserDefaults.standard.set(newValue, forKey: "supabase_access_token") }
    }

    var isAuthenticated: Bool { accessToken != nil }

    // MARK: - Auth

    func signIn(email: String, password: String) async throws {
        let url = URL(string: "\(Config.baseURL)/auth/v1/token?grant_type=password")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(Config.anonKey, forHTTPHeaderField: "apikey")
        req.httpBody = try JSONEncoder().encode(["email": email, "password": password])

        let (data, response) = try await URLSession.shared.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            struct ErrBody: Decodable { let error_description: String? }
            let msg = (try? JSONDecoder().decode(ErrBody.self, from: data))?.error_description
            throw SupabaseError.auth(msg ?? "Sign in failed. Check your email and password.")
        }

        struct AuthResp: Decodable { let access_token: String; let refresh_token: String }
        let auth = try JSONDecoder().decode(AuthResp.self, from: data)
        UserDefaults.standard.set(auth.access_token, forKey: "supabase_access_token")
        UserDefaults.standard.set(auth.refresh_token, forKey: "supabase_refresh_token")
    }

    func signOut() {
        UserDefaults.standard.removeObject(forKey: "supabase_access_token")
        UserDefaults.standard.removeObject(forKey: "supabase_refresh_token")
    }

    func refreshSession() async throws {
        guard let refreshToken = UserDefaults.standard.string(forKey: "supabase_refresh_token") else {
            throw SupabaseError.auth("No refresh token. Please sign in again.")
        }
        let url = URL(string: "\(Config.baseURL)/auth/v1/token?grant_type=refresh_token")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(Config.anonKey, forHTTPHeaderField: "apikey")
        req.httpBody = try JSONEncoder().encode(["refresh_token": refreshToken])

        let (data, response) = try await URLSession.shared.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            signOut()
            throw SupabaseError.auth("Session expired. Please sign in again.")
        }
        struct AuthResp: Decodable { let access_token: String; let refresh_token: String }
        let auth = try JSONDecoder().decode(AuthResp.self, from: data)
        UserDefaults.standard.set(auth.access_token, forKey: "supabase_access_token")
        UserDefaults.standard.set(auth.refresh_token, forKey: "supabase_refresh_token")
    }

    // MARK: - Read

    func fetchLinks() async throws -> [Link] {
        var comps = URLComponents(string: "\(Config.baseURL)/rest/v1/links")!
        var items = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "order", value: "saved_at.desc")
        ]
        if !isAuthenticated {
            items.append(URLQueryItem(name: "private", value: "eq.false"))
        }
        comps.queryItems = items
        return try await get(url: comps.url!, type: [Link].self)
    }

    func fetchCategories() async throws -> [Category] {
        var comps = URLComponents(string: "\(Config.baseURL)/rest/v1/categories")!
        comps.queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "order", value: "sort_order.asc")
        ]
        return try await get(url: comps.url!, type: [Category].self)
    }

    private func get<T: Decodable>(url: URL, type: T.Type, retried: Bool = false) async throws -> T {
        var req = URLRequest(url: url)
        req.setValue(Config.anonKey, forHTTPHeaderField: "apikey")
        if let token = accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        // If 401 and we haven't retried yet, try refreshing. If refresh fails,
        // silently clear auth and retry as guest — public content is still accessible via RLS.
        if status == 401 && !retried {
            do {
                try await refreshSession()
            } catch {
                accessToken = nil
                UserDefaults.standard.removeObject(forKey: "supabase_refresh_token")
            }
            return try await get(url: url, type: type, retried: true)
        }

        guard status == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "no body"
            print("❌ Fetch failed (\(status)): \(body.prefix(300))")
            throw SupabaseError.fetch
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? "unreadable"
            print("❌ Decode error for \(T.self): \(error)")
            print("❌ Raw JSON: \(raw.prefix(500))")
            throw SupabaseError.decode(error.localizedDescription + " | Raw: " + raw.prefix(200))
        }
    }

    // MARK: - Write

    func insertLink(_ link: Link) async throws {
        let url = URL(string: "\(Config.baseURL)/rest/v1/links")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(Config.anonKey, forHTTPHeaderField: "apikey")
        if let token = accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        req.httpBody = try encoder.encode(link)

        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SupabaseError.update
        }
    }

    func updateLink(id: String, fields: [String: Any], retried: Bool = false) async throws {
        var comps = URLComponents(string: "\(Config.baseURL)/rest/v1/links")!
        comps.queryItems = [URLQueryItem(name: "id", value: "eq.\(id)")]
        let url = comps.url!
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(Config.anonKey, forHTTPHeaderField: "apikey")
        if let token = accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: fields)

        let (_, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 && !retried {
            try await refreshSession()
            try await updateLink(id: id, fields: fields, retried: true)
            return
        }
        guard (200...299).contains(status) else {
            throw SupabaseError.update
        }
    }

    func deleteLink(id: String) async throws {
        var comps = URLComponents(string: "\(Config.baseURL)/rest/v1/links")!
        comps.queryItems = [URLQueryItem(name: "id", value: "eq.\(id)")]
        let url = comps.url!
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue(Config.anonKey, forHTTPHeaderField: "apikey")
        if let token = accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SupabaseError.update
        }
    }

    // MARK: - Recipients

    func fetchRecipients() async throws -> [Recipient] {
        var comps = URLComponents(string: "\(Config.baseURL)/rest/v1/recipients")!
        comps.queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "order", value: "name.asc")
        ]
        return try await get(url: comps.url!, type: [Recipient].self)
    }

    func createRecipient(name: String, slug: String, retried: Bool = false) async throws -> Recipient {
        for attempt in 0..<5 {
            let candidateSlug = attempt == 0 ? slug : "\(slug)-\(attempt + 1)"
            let url = URL(string: "\(Config.baseURL)/rest/v1/recipients")!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("return=representation", forHTTPHeaderField: "Prefer")
            req.setValue(Config.anonKey, forHTTPHeaderField: "apikey")
            if let token = accessToken {
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            req.httpBody = try JSONSerialization.data(withJSONObject: ["name": name, "slug": candidateSlug])

            let (data, response) = try await URLSession.shared.data(for: req)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0

            if status == 401 && !retried {
                try await refreshSession()
                return try await createRecipient(name: name, slug: slug, retried: true)
            }
            if status == 409 { continue } // slug conflict, try next
            guard (200...299).contains(status) else {
                let raw = String(data: data, encoding: .utf8) ?? ""
                print("❌ createRecipient failed (\(status)): \(raw.prefix(300))")
                if raw.contains("23505") || raw.contains("duplicate") { continue }
                throw SupabaseError.update
            }

            let created = try decoder.decode([Recipient].self, from: data)
            guard let recipient = created.first else { throw SupabaseError.update }
            return recipient
        }
        throw SupabaseError.update
    }

    func createBatch(recipientId: String, linkIds: [String], note: String?, enrichedMessage: String?, retried: Bool = false) async throws {
        let url = URL(string: "\(Config.baseURL)/rest/v1/recipient_batches")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(Config.anonKey, forHTTPHeaderField: "apikey")
        if let token = accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        var body: [String: Any] = ["recipient_id": recipientId, "link_ids": linkIds]
        if let n = note, !n.isEmpty { body["note"] = n }
        if let em = enrichedMessage, !em.isEmpty { body["enriched_message"] = em }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 && !retried {
            try await refreshSession()
            try await createBatch(recipientId: recipientId, linkIds: linkIds, note: note, enrichedMessage: enrichedMessage, retried: true)
            return
        }
        guard (200...299).contains(status) else {
            let raw = String(data: data, encoding: .utf8) ?? ""
            print("❌ createBatch failed (\(status)): \(raw.prefix(300))")
            throw SupabaseError.update
        }
    }

    // MARK: - Collections

    func createCollection(recipient: String?, message: String?, enrichedMessage: String?, linkIds: [String]) async throws -> String {
        let collectionId = String(Int(Date().timeIntervalSince1970 * 1000), radix: 36)

        let url = URL(string: "\(Config.baseURL)/rest/v1/collections")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(Config.anonKey, forHTTPHeaderField: "apikey")
        if let token = accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body: [String: Any] = [
            "id": collectionId,
            "link_ids": linkIds,
            "created_at": ISO8601DateFormatter().string(from: Date())
        ]
        if let r = recipient, !r.isEmpty { body["recipient"] = r }
        if let m = message, !m.isEmpty { body["message"] = m }
        if let em = enrichedMessage, !em.isEmpty { body["enriched_message"] = em }

        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SupabaseError.update
        }

        return collectionId
    }
}
