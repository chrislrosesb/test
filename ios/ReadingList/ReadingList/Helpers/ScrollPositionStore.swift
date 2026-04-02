import Foundation

/// Persists per-article scroll positions in iCloud KV store (syncs across devices)
/// with a UserDefaults fallback for when iCloud is unavailable.
///
/// iCloud setup: Xcode → Signing & Capabilities → + Capability → iCloud → check "Key-value storage"
/// Without that capability NSUbiquitousKeyValueStore silently no-ops; UserDefaults handles it locally.
final class ScrollPositionStore {
    static let shared = ScrollPositionStore()
    private init() {}

    private let kv = NSUbiquitousKeyValueStore.default
    private let ud = UserDefaults.standard

    private func key(_ linkId: String, _ readerMode: Bool) -> String {
        "sp_\(readerMode ? "r" : "w")_\(linkId)"
    }

    /// Save scroll position. Positions ≤ 50pt are ignored (treat as "top").
    func save(linkId: String, readerMode: Bool, y: Double) {
        guard y > 50 else { return }
        let k = key(linkId, readerMode)
        kv.set(y, forKey: k)
        kv.synchronize()
        ud.set(y, forKey: k)
    }

    /// Returns saved scroll position, or 0 if none stored.
    func get(linkId: String, readerMode: Bool) -> Double {
        let k = key(linkId, readerMode)
        let v = kv.double(forKey: k)
        return v > 0 ? v : ud.double(forKey: k)
    }
}
