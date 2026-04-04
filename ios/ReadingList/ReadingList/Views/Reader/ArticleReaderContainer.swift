import SwiftUI
import WebKit
import SafariServices

/// Full-screen immersive reader with swipe navigation between articles
struct ArticleReaderContainer: View {
    let links: [Link]
    let initialIndex: Int
    let vm: LibraryViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var currentIndex: Int
    @State private var showInfo = false
    @State private var showTypography = false
    @State private var showFinished = false
    @State private var showSafariView = false
    @State private var isReaderMode = false
    @State private var reflectLink: Link? = nil
    @State private var youtubeVideoID: String = ""
    @State private var showYouTubePlayer = false

    // Auto-open social platforms (Threads, X, Instagram) in Safari View so shared login works
    static func isSocialURL(_ urlString: String) -> Bool {
        guard let host = URL(string: urlString)?.host?.lowercased() else { return false }
        return host.contains("threads.net") || host.contains("x.com") ||
               host.contains("twitter.com") || host.contains("instagram.com")
    }

    // Extract YouTube video ID from various URL formats
    static func extractYouTubeID(_ urlString: String) -> String? {
        guard let url = URL(string: urlString), let host = url.host?.lowercased() else { return nil }

        // youtu.be/VIDEO_ID
        if host.contains("youtu.be") {
            let path = url.path.dropFirst() // Remove leading "/"
            return path.isEmpty ? nil : String(path)
        }

        // youtube.com, youtube-nocookie.com: look for v= parameter or /embed/
        if host.contains("youtube") {
            // Check for /embed/VIDEO_ID
            if url.path.contains("/embed/") {
                let components = url.path.split(separator: "/")
                if let index = components.firstIndex(of: "embed"),
                   components.index(after: index) < components.endIndex {
                    return String(components[components.index(after: index)])
                }
            }

            // Check for v= parameter
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
               let queryItems = components.queryItems,
               let videoID = queryItems.first(where: { $0.name == "v" })?.value {
                return videoID
            }
        }

        return nil
    }

    var isSocialLink: Bool { Self.isSocialURL(currentLink.url) }

    @AppStorage("readerFontSize") private var fontSize: Double = 17
    @AppStorage("readerFont") private var fontRaw: String = "system"
    @AppStorage("readerTheme") private var themeRaw: String = "dark"

    init(links: [Link], initialIndex: Int, vm: LibraryViewModel) {
        self.links = links
        self.initialIndex = initialIndex
        self.vm = vm
        self._currentIndex = State(initialValue: initialIndex)
    }

    var currentLink: Link {
        links[min(currentIndex, links.count - 1)]
    }

    var font: ReaderFont { ReaderFont(rawValue: fontRaw) ?? .system }
    var theme: ReaderTheme { ReaderTheme(rawValue: themeRaw) ?? .dark }

    var body: some View {
        NavigationStack {
            readerContent
                .gesture(swipeGesture)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // Leading: close (always dismisses, no prompt)
                    ToolbarItem(placement: .topBarLeading) {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .medium))
                        }
                    }

                    // Trailing: checkmark (done), reader toggle, info, overflow
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        // Checkmark — mark as done / finished reading
                        Button { showFinished = true } label: {
                            Image(systemName: currentLink.status == "done" ? "checkmark.circle.fill" : "checkmark.circle")
                                .font(.system(size: 17))
                                .foregroundStyle(currentLink.status == "done" ? .green : .primary)
                        }
                        // Reader/Web toggle
                        Button {
                            withAnimation(.spring(duration: 0.3)) { isReaderMode.toggle() }
                        } label: {
                            Image(systemName: isReaderMode ? "globe" : "doc.text")
                        }

                        // Reflect (direct button)
                        Button { reflectLink = currentLink } label: {
                            Image(systemName: "sparkles.rectangle.stack")
                        }

                        // Article info (promoted from overflow)
                        Button { showInfo = true } label: {
                            Image(systemName: "info.circle")
                        }

                        // Overflow: everything else
                        Menu {
                            Button { shareArticle() } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            Button { showTypography = true } label: {
                                Label("Typography", systemImage: "textformat.size")
                            }
                            Button { showSafariView = true } label: {
                                Label("Open with Login", systemImage: "person.badge.key")
                            }
                            Button {
                                guard let url = URL(string: currentLink.url) else { return }
                                UIApplication.shared.open(url)
                            } label: {
                                Label("Open in Safari", systemImage: "safari")
                            }
                            Button {
                                UIPasteboard.general.string = currentLink.url
                            } label: {
                                Label("Copy URL", systemImage: "doc.on.doc")
                            }
                            Divider()
                            Text("\(currentIndex + 1) of \(links.count)")
                        } label: {
                            Image(systemName: "ellipsis")
                        }
                    }
                }
        }
        .sheet(isPresented: $showInfo) {
            ArticleDetailView(link: currentLink)
                .environment(vm)
        }
        .sheet(isPresented: $showTypography) {
            TypographySheet()
        }
        .sheet(isPresented: $showFinished) {
            FinishedReadingSheet(link: currentLink, vm: vm, onDismiss: {
                showFinished = false
                dismiss()
            }, onReflect: { link in
                reflectLink = link
            })
        }
        .sheet(item: $reflectLink) { link in
            ReflectionView(link: link, vm: vm)
        }
        .sheet(isPresented: $showSafariView) {
            if let url = URL(string: currentLink.url) {
                SafariSheet(url: url)
                    .ignoresSafeArea()
            }
        }
        .sheet(isPresented: $showYouTubePlayer) {
            YouTubePlayerSheet(videoID: youtubeVideoID)
        }
        .onAppear {
            if isSocialLink { showSafariView = true }
        }
        .onChange(of: currentIndex) { _, _ in
            if isSocialLink { showSafariView = true }
        }
    }

    // MARK: - Reader Content

    @ViewBuilder
    var readerContent: some View {
        if let webURL = URL(string: currentLink.url) {
            if isReaderMode {
                ReaderWebView(
                    url: webURL,
                    fontSize: fontSize,
                    font: font,
                    theme: theme,
                    onFallback: { withAnimation { isReaderMode = false } },
                    linkId: currentLink.id
                )
                .id(currentLink.id + "reader")
                .ignoresSafeArea(edges: .bottom)
            } else {
                WebView(url: webURL, linkId: currentLink.id) { videoID in
                    youtubeVideoID = videoID
                    showYouTubePlayer = true
                }
                .id(currentLink.id + "web")
                .ignoresSafeArea(edges: .bottom)
            }
        } else {
            ContentUnavailableView("Invalid URL", systemImage: "link.badge.plus")
        }
    }

    // MARK: - Swipe Gesture

    var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 50)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > abs(vertical) else { return }

                if horizontal < -50 && currentIndex < links.count - 1 {
                    withAnimation(.spring(duration: 0.3)) { currentIndex += 1 }
                } else if horizontal > 50 && currentIndex > 0 {
                    withAnimation(.spring(duration: 0.3)) { currentIndex -= 1 }
                }
            }
    }

    // MARK: - Share

    func shareArticle() {
        guard let url = URL(string: currentLink.url) else { return }
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            // Find the topmost presented controller
            var topController = root
            while let presented = topController.presentedViewController {
                topController = presented
            }
            topController.present(av, animated: true)
        }
    }
}

// MARK: - Safari View (shares Safari's cookies/logins)

struct SafariSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.preferredBarTintColor = .systemBackground
        vc.preferredControlTintColor = .tintColor
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - YouTube Player Sheet

struct YouTubePlayerSheet: View {
    let videoID: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            YouTubePlayerView(videoID: videoID)
                .ignoresSafeArea(edges: .bottom)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.down")
                        }
                    }
                }
        }
    }
}

// MARK: - YouTube Player WebView

struct YouTubePlayerView: UIViewRepresentable {
    let videoID: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsAirPlayForMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false

        // Minimal UI YouTube embed parameters:
        // - modestbranding=1: Hide YouTube logo
        // - rel=0: Minimize related videos (YouTube only shows same-channel videos)
        // - controls=1: Show player controls
        // - fs=1: Enable fullscreen button
        // - playsinline=1: Play inline in view (required for iOS)
        // - autoplay=1: Start playing automatically
        // - mute=1: Muted autoplay (required for iOS autoplay to work)
        let htmlString = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                * { margin: 0; padding: 0; }
                body { background: #000; width: 100vw; height: 100vh; }
                iframe {
                    width: 100%;
                    height: 100%;
                    border: none;
                    display: block;
                }
            </style>
        </head>
        <body>
            <iframe
                src="https://www.youtube.com/embed/\(videoID)?autoplay=1&mute=1&modestbranding=1&rel=0&controls=1&fs=1&playsinline=1"
                allow="autoplay; encrypted-media; fullscreen"
                allowfullscreen>
            </iframe>
        </body>
        </html>
        """

        webView.loadHTMLString(htmlString, baseURL: nil)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}

