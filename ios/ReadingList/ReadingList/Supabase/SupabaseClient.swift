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

    private func get<T: Decodable>(url: URL, type: T.Type) async throws -> T {
        var req = URLRequest(url: url)
        req.setValue(Config.anonKey, forHTTPHeaderField: "apikey")
        if let token = accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "no body"
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

    func updateLink(id: String, fields: [String: Any]) async throws {
        let url = URL(string: "\(Config.baseURL)/rest/v1/links?id=eq.\(id)")!
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(Config.anonKey, forHTTPHeaderField: "apikey")
        if let token = accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: fields)

        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SupabaseError.update
        }
    }

    func deleteLink(id: String) async throws {
        let url = URL(string: "\(Config.baseURL)/rest/v1/links?id=eq.\(id)")!
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
}
