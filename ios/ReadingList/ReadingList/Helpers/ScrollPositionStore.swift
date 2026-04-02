import Foundation

/// Persists per-article scroll positions using UserDefaults (local).
/// iCloud KV sync can be added later once a developer account is active:
///   Xcode → Signing & Capabilities → iCloud → Key-value storage
final class ScrollPositionStore {
    static let shared = ScrollPositionStore()
    private init() {}

    private let ud = UserDefaults.standard

    private func key(_ linkId: String, _ readerMode: Bool) -> String {
        "sp_\(readerMode ? "r" : "w")_\(linkId)"
    }

    func save(linkId: String, readerMode: Bool, y: Double) {
        guard y > 50, !linkId.isEmpty else { return }
        ud.set(y, forKey: key(linkId, readerMode))
    }

    func get(linkId: String, readerMode: Bool) -> Double {
        guard !linkId.isEmpty else { return 0 }
        return ud.double(forKey: key(linkId, readerMode))
    }
}
