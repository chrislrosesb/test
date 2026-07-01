import UIKit
import SwiftUI
import UniformTypeIdentifiers

private enum Config {
    static let baseURL = "https://ownqyyfgferczpdgihgr.supabase.co"
    static let anonKey = "sb_publishable_RPJSQlVO4isbKnZve8NlWg_55EO350Y"
    static let appGroup = "group.com.aseva.procrastinate"
}

final class ShareViewController: UIViewController {
    private let model = ShareModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        let host = UIHostingController(rootView: ShareCard(model: model))
        host.view.backgroundColor = .clear
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)

        model.finish = { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        Task { await model.run(items: items) }
    }
}

// MARK: - Model

private struct ShareError: Error { let message: String }

private struct LinkMeta {
    var title: String?
    var description: String?
    var image: String?
    var favicon: String?
    var domain: String?
}

@Observable
final class ShareModel {
    enum Phase { case saving, saved(String), failed(String) }
    var phase: Phase = .saving
    var finish: () -> Void = {}

    private var defaults: UserDefaults { UserDefaults(suiteName: Config.appGroup) ?? .standard }

    func run(items: [NSExtensionItem]) async {
        do {
            guard defaults.string(forKey: "supabase_access_token") != nil else {
                throw ShareError(message: "Open Procrastinate and sign in first.")
            }
            let url = try await extractURL(items: items)
            let meta = await fetchMetadata(for: url)
            try await insertLink(url: url, meta: meta)
            phase = .saved(meta.title ?? url.host() ?? url.absoluteString)
            try? await Task.sleep(for: .seconds(1.2))
            finish()
        } catch let e as ShareError {
            phase = .failed(e.message)
        } catch {
            phase = .failed("Couldn't save. Try again from the app.")
        }
    }

    // MARK: URL extraction

    private func extractURL(items: [NSExtensionItem]) async throws -> URL {
        for item in items {
            for provider in item.attachments ?? [] where provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                let loaded = try await provider.loadItem(forTypeIdentifier: UTType.url.identifier)
                if let url = loaded as? URL, url.scheme?.hasPrefix("http") == true { return url }
                if let data = loaded as? Data, let url = URL(dataRepresentation: data, relativeTo: nil),
                   url.scheme?.hasPrefix("http") == true { return url }
            }
        }
        throw ShareError(message: "No link found in the shared content.")
    }

    // MARK: Metadata

    private func fetchMetadata(for url: URL) async -> LinkMeta {
        var meta = LinkMeta()
        var domain = url.host() ?? ""
        if domain.hasPrefix("www.") { domain = String(domain.dropFirst(4)) }
        meta.domain = domain
        meta.favicon = "https://www.google.com/s2/favicons?domain=\(domain)&sz=64"

        // YouTube: oEmbed gives a reliable title + stable (non-expiring) thumbnail
        if domain == "youtube.com" || domain == "youtu.be", let videoId = youTubeId(url) {
            meta.image = "https://img.youtube.com/vi/\(videoId)/maxresdefault.jpg"
            var comps = URLComponents(string: "https://www.youtube.com/oembed")!
            comps.queryItems = [URLQueryItem(name: "url", value: url.absoluteString),
                                URLQueryItem(name: "format", value: "json")]
            if let (data, _) = try? await URLSession.shared.data(from: comps.url!),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                meta.title = obj["title"] as? String
                if let author = obj["author_name"] as? String { meta.description = "By \(author)" }
            }
            return meta
        }

        var req = URLRequest(url: url, timeoutInterval: 8)
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1",
                     forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            return meta
        }
        meta.title = metaContent(html, "og:title") ?? htmlTitle(html)
        meta.description = metaContent(html, "og:description") ?? metaContent(html, "description")
        meta.image = metaContent(html, "og:image")
        return meta
    }

    private func youTubeId(_ url: URL) -> String? {
        if url.host()?.contains("youtu.be") == true {
            return url.pathComponents.count > 1 ? url.pathComponents[1] : nil
        }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "v" })?.value
    }

    private func metaContent(_ html: String, _ key: String) -> String? {
        let patterns = [
            "<meta[^>]+(?:property|name)\\s*=\\s*[\"']\(key)[\"'][^>]*?content\\s*=\\s*[\"']([^\"']+)[\"']",
            "<meta[^>]+content\\s*=\\s*[\"']([^\"']+)[\"'][^>]*?(?:property|name)\\s*=\\s*[\"']\(key)[\"']"
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                  let range = Range(match.range(at: 1), in: html) else { continue }
            return decodeEntities(String(html[range]))
        }
        return nil
    }

    private func htmlTitle(_ html: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: "<title[^>]*>([^<]+)</title>", options: .caseInsensitive),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else { return nil }
        return decodeEntities(String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func decodeEntities(_ s: String) -> String {
        s.replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }

    // MARK: Supabase insert

    private func insertLink(url: URL, meta: LinkMeta, retried: Bool = false) async throws {
        var body: [String: Any] = [
            "id": UUID().uuidString,
            "url": url.absoluteString,
            "status": "to-read",
            "read": false,
            "private": false,
            "saved_at": ISO8601DateFormatter().string(from: Date())
        ]
        if let t = meta.title { body["title"] = t }
        if let d = meta.description { body["description"] = d }
        if let i = meta.image { body["image"] = i }
        if let f = meta.favicon { body["favicon"] = f }
        if let dm = meta.domain { body["domain"] = dm }

        var req = URLRequest(url: URL(string: "\(Config.baseURL)/rest/v1/links")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(Config.anonKey, forHTTPHeaderField: "apikey")
        if let token = defaults.string(forKey: "supabase_access_token") {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 && !retried {
            try await refreshSession()
            try await insertLink(url: url, meta: meta, retried: true)
            return
        }
        guard (200...299).contains(status) else {
            throw ShareError(message: "Save failed (\(status)). Open the app and sign in again.")
        }
    }

    private func refreshSession() async throws {
        guard let refreshToken = defaults.string(forKey: "supabase_refresh_token") else {
            throw ShareError(message: "Open Procrastinate and sign in first.")
        }
        var req = URLRequest(url: URL(string: "\(Config.baseURL)/auth/v1/token?grant_type=refresh_token")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(Config.anonKey, forHTTPHeaderField: "apikey")
        req.httpBody = try JSONEncoder().encode(["refresh_token": refreshToken])

        let (data, response) = try await URLSession.shared.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw ShareError(message: "Session expired. Open the app and sign in again.")
        }
        struct AuthResp: Decodable { let access_token: String; let refresh_token: String }
        let auth = try JSONDecoder().decode(AuthResp.self, from: data)
        defaults.set(auth.access_token, forKey: "supabase_access_token")
        defaults.set(auth.refresh_token, forKey: "supabase_refresh_token")
    }
}

// MARK: - UI

struct ShareCard: View {
    let model: ShareModel

    var body: some View {
        VStack(spacing: 14) {
            switch model.phase {
            case .saving:
                ProgressView()
                    .controlSize(.large)
                Text("Saving…")
                    .font(.headline)
            case .saved(let title):
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.green)
                Text("Saved to Procrastinate")
                    .font(.headline)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            case .failed(let message):
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                Button("Done") { model.finish() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(28)
        .frame(maxWidth: 300)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.default, value: phaseKey)
    }

    private var phaseKey: Int {
        switch model.phase {
        case .saving: 0
        case .saved: 1
        case .failed: 2
        }
    }
}
