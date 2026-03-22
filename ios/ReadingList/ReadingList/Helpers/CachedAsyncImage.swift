import SwiftUI

/// In-memory image cache shared across all CachedAsyncImage instances.
final class ImageCache {
    static let shared = ImageCache()
    private var cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 100 * 1024 * 1024 // 100 MB
    }

    func get(_ url: String) -> UIImage? {
        cache.object(forKey: url as NSString)
    }

    func set(_ url: String, image: UIImage) {
        cache.setObject(image, forKey: url as NSString)
    }
}

/// Drop-in replacement for AsyncImage that caches loaded images in memory.
struct CachedAsyncImage: View {
    let url: URL?
    let content: (Image) -> AnyView
    let placeholder: () -> AnyView

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> some View,
        @ViewBuilder placeholder: @escaping () -> some View
    ) {
        self.url = url
        self.content = { AnyView(content($0)) }
        self.placeholder = { AnyView(placeholder()) }
    }

    @State private var image: UIImage? = nil
    @State private var isLoading = false

    var body: some View {
        Group {
            if let image {
                content(Image(uiImage: image))
            } else {
                placeholder()
                    .task(id: url) {
                        await loadImage()
                    }
            }
        }
    }

    func loadImage() async {
        guard let url, !isLoading else { return }

        // Check cache first
        if let cached = ImageCache.shared.get(url.absoluteString) {
            self.image = cached
            return
        }

        isLoading = true
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let uiImage = UIImage(data: data) {
                ImageCache.shared.set(url.absoluteString, image: uiImage)
                self.image = uiImage
            }
        } catch {
            // Failed to load — stay on placeholder
        }
        isLoading = false
    }
}
