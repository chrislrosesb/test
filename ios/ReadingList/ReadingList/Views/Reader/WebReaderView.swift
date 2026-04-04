import SwiftUI
import WebKit

// MARK: - Reader Theme & Font

enum ReaderTheme: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case dark, light, sepia

    var label: String {
        switch self {
        case .dark: return "Dark"
        case .light: return "Light"
        case .sepia: return "Sepia"
        }
    }

    var background: String {
        switch self {
        case .dark: return "#1c1c1e"
        case .light: return "#ffffff"
        case .sepia: return "#f5ead8"
        }
    }

    var text: String {
        switch self {
        case .dark: return "#e5e5ea"
        case .light: return "#1c1c1e"
        case .sepia: return "#3d2b1f"
        }
    }

    var link: String {
        switch self {
        case .dark: return "#4f9ef8"
        case .light: return "#4f46e5"
        case .sepia: return "#8b5c30"
        }
    }
}

enum ReaderFont: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case system, newYork, iowan, palatino, charter, serif, mono

    var label: String {
        switch self {
        case .system:   return "System"
        case .newYork:  return "New York"
        case .iowan:    return "Iowan Old Style"
        case .palatino: return "Palatino"
        case .charter:  return "Charter"
        case .serif:    return "Georgia"
        case .mono:     return "Mono"
        }
    }

    var css: String {
        switch self {
        case .system:   return "-apple-system, 'SF Pro Text', sans-serif"
        case .newYork:  return "ui-serif, Georgia, serif"
        case .iowan:    return "'Iowan Old Style', ui-serif, Georgia, serif"
        case .palatino: return "'Palatino-Roman', Palatino, Georgia, serif"
        case .charter:  return "'Charter-Roman', Charter, Georgia, serif"
        case .serif:    return "Georgia, serif"
        case .mono:     return "'SF Mono', 'Courier New', monospace"
        }
    }

    var previewFont: Font {
        switch self {
        case .system:   return .body
        case .newYork:  return .system(.body, design: .serif)
        case .iowan:    return .custom("IowanOldStyle-Roman", size: 17)
        case .palatino: return .custom("Palatino-Roman", size: 17)
        case .charter:  return .custom("Charter-Roman", size: 17)
        case .serif:    return .custom("Georgia", size: 17)
        case .mono:     return .system(.body, design: .monospaced)
        }
    }
}

// MARK: - Main View

struct WebReaderView: View {
    let url: String
    let title: String

    @Environment(\.dismiss) private var dismiss

    @State private var isReaderMode = false
    @State private var showTypography = false

    @AppStorage("readerFontSize") private var fontSize: Double = 17
    @AppStorage("readerFont") private var fontRaw: String = ReaderFont.system.rawValue
    @AppStorage("readerTheme") private var themeRaw: String = ReaderTheme.dark.rawValue

    var font: ReaderFont { ReaderFont(rawValue: fontRaw) ?? .system }
    var theme: ReaderTheme { ReaderTheme(rawValue: themeRaw) ?? .dark }

    var body: some View {
        NavigationStack {
            Group {
                if let webURL = URL(string: url) {
                    if isReaderMode {
                        ReaderWebView(
                            url: webURL,
                            fontSize: fontSize,
                            font: font,
                            theme: theme,
                            onFallback: {
                                withAnimation { isReaderMode = false }
                            }
                        )
                        .ignoresSafeArea(edges: .bottom)
                    } else {
                        WebView(url: webURL)
                            .ignoresSafeArea(edges: .bottom)
                    }
                } else {
                    ContentUnavailableView("Invalid URL", systemImage: "link.badge.plus")
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if isReaderMode {
                        Button {
                            showTypography = true
                        } label: {
                            Image(systemName: "textformat.size")
                        }
                    }
                    Button {
                        withAnimation(.spring(duration: 0.3, bounce: 0.4)) {
                            isReaderMode.toggle()
                        }
                    } label: {
                        Label(
                            isReaderMode ? "Web" : "Reader",
                            systemImage: isReaderMode ? "globe" : "doc.text"
                        )
                        .labelStyle(.titleAndIcon)
                    }
                    .tint(isReaderMode ? .secondary : .accentColor)
                    Menu {
                        Button {
                            guard let webURL = URL(string: url) else { return }
                            UIApplication.shared.open(webURL)
                        } label: {
                            Label("Open in Safari", systemImage: "safari")
                        }
                        Button {
                            UIPasteboard.general.string = url
                        } label: {
                            Label("Copy URL", systemImage: "doc.on.doc")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showTypography) {
            TypographySheet()
        }
    }
}

// MARK: - Typography Sheet

struct TypographySheet: View {
    @AppStorage("readerFontSize") private var fontSize: Double = 17
    @AppStorage("readerFont") private var fontRaw: String = ReaderFont.system.rawValue
    @AppStorage("readerTheme") private var themeRaw: String = ReaderTheme.dark.rawValue
    @Environment(\.dismiss) private var dismiss

    private let fonts: [ReaderFont] = ReaderFont.allCases

    private let themes: [(ReaderTheme, String)] = [
        (.dark, "#1c1c1e"),
        (.light, "#ffffff"),
        (.sepia, "#f5ead8")
    ]

    var body: some View {
        NavigationStack {
            List {
                Section("Font Size") {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Aa").font(.caption)
                            Slider(value: $fontSize, in: 13...24, step: 1)
                            Text("Aa").font(.title3)
                        }
                        Text("Preview: \(Int(fontSize))pt")
                            .font(.system(size: fontSize))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.vertical, 4)
                }

                Section("Font") {
                    ForEach(fonts) { f in
                        fontRow(f, preview: f.previewFont)
                    }
                }

                Section("Theme") {
                    themeRow(.dark)
                    themeRow(.light)
                    themeRow(.sepia)
                }
            }
            .navigationTitle("Typography")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    func fontRow(_ f: ReaderFont, preview: Font) -> some View {
        Button {
            fontRaw = f.rawValue
        } label: {
            HStack {
                Text(f.label)
                    .font(preview)
                    .foregroundStyle(.primary)
                Spacer()
                if fontRaw == f.rawValue {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    func themeRow(_ t: ReaderTheme) -> some View {
        Button {
            themeRaw = t.rawValue
        } label: {
            HStack {
                Circle()
                    .fill(Color(hex: t.background))
                    .frame(width: 22, height: 22)
                    .overlay(Circle().strokeBorder(.secondary.opacity(0.3), lineWidth: 1))
                Text(t.label).foregroundStyle(.primary)
                Spacer()
                if themeRaw == t.rawValue {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Reader Web View (Readability-based extraction)

struct ReaderWebView: UIViewRepresentable {
    let url: URL
    let fontSize: Double
    let font: ReaderFont
    let theme: ReaderTheme
    let onFallback: () -> Void
    var linkId: String = ""

    func makeCoordinator() -> Coordinator {
        Coordinator(fontSize: fontSize, font: font, theme: theme, onFallback: onFallback, linkId: linkId)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true

        let script = WKUserScript(
            source: ReadabilityJS.source,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(script)
        config.userContentController.add(context.coordinator, name: "readability")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        context.coordinator.webView = webView

        // KVO scroll observation (same pattern as WebView — don't set scrollView.delegate)
        context.coordinator.scrollObservation = webView.scrollView.observe(
            \.contentOffset, options: [.new]
        ) { [weak c = context.coordinator] scrollView, _ in
            c?.schedulePositionSave(y: Double(scrollView.contentOffset.y))
        }

        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let c = context.coordinator
        let changed = c.fontSize != fontSize || c.font.id != font.id || c.theme.id != theme.id
        c.fontSize = fontSize
        c.font = font
        c.theme = theme
        if c.hasInjected && changed {
            c.reapplyStyles(webView: webView)
        }
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "readability")
        let y = Double(webView.scrollView.contentOffset.y)
        ScrollPositionStore.shared.save(linkId: coordinator.linkId, readerMode: true, y: y)
        coordinator.scrollObservation?.invalidate()
        coordinator.saveTimer?.invalidate()
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var fontSize: Double
        var font: ReaderFont
        var theme: ReaderTheme
        let onFallback: () -> Void
        let linkId: String
        weak var webView: WKWebView?
        var hasInjected = false
        var scrollObservation: NSKeyValueObservation?
        var saveTimer: Timer?

        init(fontSize: Double, font: ReaderFont, theme: ReaderTheme, onFallback: @escaping () -> Void, linkId: String) {
            self.fontSize = fontSize
            self.font = font
            self.theme = theme
            self.onFallback = onFallback
            self.linkId = linkId
        }

        func schedulePositionSave(y: Double) {
            saveTimer?.invalidate()
            saveTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { [weak self] _ in
                guard let self else { return }
                ScrollPositionStore.shared.save(linkId: self.linkId, readerMode: true, y: y)
            }
        }

        // Called when page finishes loading — trigger extraction via JS
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !hasInjected else { return }
            // Give JS-rendered pages a moment to settle, then call extractArticle()
            // and route the result through the message handler (reliable on Mac Catalyst)
            let trigger = """
            setTimeout(function() {
                var result = window.extractArticle ? window.extractArticle() : null;
                if (result) {
                    window.webkit.messageHandlers.readability.postMessage(result);
                } else {
                    window.webkit.messageHandlers.readability.postMessage('{"success":false,"reason":"not_ready"}');
                }
            }, 900);
            """
            webView.evaluateJavaScript(trigger, completionHandler: nil)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.onFallback() }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.onFallback() }
        }

        // Re-apply CSS styles to already-rendered HTML (called when font/theme/size changes)
        func reapplyStyles(webView: WKWebView) {
            let js = """
            (function() {
                var b = document.body;
                if (!b) return;
                b.style.fontFamily = '\(font.css)';
                b.style.fontSize = '\(Int(fontSize))px';
                b.style.background = '\(theme.background)';
                b.style.color = '\(theme.text)';
                var links = document.querySelectorAll('a');
                for (var i = 0; i < links.length; i++) {
                    links[i].style.color = '\(theme.link)';
                }
            })();
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        // Receive extraction result from JS
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "readability",
                  let jsonString = message.body as? String,
                  let data = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let success = json["success"] as? Bool, success,
                  let content = json["content"] as? String,
                  !content.isEmpty else {
                DispatchQueue.main.async { self.onFallback() }
                return
            }
            let title = json["title"] as? String ?? ""
            let byline = json["byline"] as? String ?? ""
            let html = buildHTML(title: title, byline: byline, content: content)
            DispatchQueue.main.async {
                self.hasInjected = true
                self.webView?.loadHTMLString(html, baseURL: nil)
                // Restore saved position after the HTML renders
                let saved = ScrollPositionStore.shared.get(linkId: self.linkId, readerMode: true)
                if saved > 50 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                        self?.webView?.evaluateJavaScript("window.scrollTo(0, \(saved))", completionHandler: nil)
                    }
                }
            }
        }

        private func buildHTML(title: String, byline: String, content: String) -> String {
            let bylineHTML = byline.isEmpty ? "" : "<p class=\"reader-byline\">\(byline)</p>"
            return """
            <!DOCTYPE html>
            <html>
            <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=3">
            <style>
            * { box-sizing: border-box; -webkit-text-size-adjust: none; }
            body {
                font-family: \(font.css);
                font-size: \(fontSize)px;
                line-height: 1.7;
                max-width: 700px;
                margin: 0 auto;
                padding: 24px 20px 80px;
                background: \(theme.background);
                color: \(theme.text);
            }
            h1.reader-title { font-size: 1.45em; line-height: 1.3; margin: 0 0 6px; }
            p.reader-byline { font-size: 0.82em; opacity: 0.55; margin: 0 0 24px; }
            h2 { font-size: 1.25em; line-height: 1.35; }
            h3 { font-size: 1.1em; }
            p { margin: 0 0 1em; }
            img { max-width: 100%; height: auto; border-radius: 8px; margin: 12px 0; display: block; }
            a { color: \(theme.link); text-decoration: none; }
            pre { background: rgba(128,128,128,0.15); padding: 14px; border-radius: 8px; overflow-x: auto; font-size: 0.88em; }
            code { font-family: 'SF Mono', monospace; font-size: 0.88em; background: rgba(128,128,128,0.15); padding: 2px 5px; border-radius: 3px; }
            blockquote { border-left: 3px solid rgba(128,128,128,0.4); margin: 16px 0; padding: 4px 0 4px 16px; opacity: 0.85; }
            figure { margin: 16px 0; }
            figcaption { font-size: 0.82em; opacity: 0.65; text-align: center; margin-top: 6px; }
            table { width: 100%; border-collapse: collapse; font-size: 0.9em; }
            td, th { padding: 8px 10px; border: 1px solid rgba(128,128,128,0.25); }
            hr { border: none; border-top: 1px solid rgba(128,128,128,0.25); margin: 24px 0; }
            </style>
            </head>
            <body>
            <h1 class="reader-title">\(title)</h1>
            \(bylineHTML)
            \(content)
            </body>
            </html>
            """
        }
    }
}

// MARK: - Full WebView (unchanged)

// MARK: - WKWebView pool — reuses the last N web views so revisiting an article is instant

final class WebViewPool {
    static let shared = WebViewPool()
    private var pool: [(linkId: String, webView: WKWebView)] = []
    private let maxSize = 5

    /// Removes and returns the cached web view for this linkId, or nil if not cached.
    func checkout(linkId: String) -> WKWebView? {
        guard let idx = pool.firstIndex(where: { $0.linkId == linkId }) else { return nil }
        let wv = pool[idx].webView
        pool.remove(at: idx)
        return wv
    }

    /// Returns a web view to the pool. Evicts least-recently-used if over capacity.
    func checkin(linkId: String, webView: WKWebView) {
        pool.removeAll { $0.linkId == linkId }
        pool.insert((linkId, webView), at: 0)
        if pool.count > maxSize { pool.removeLast() }
    }
}

// MARK: - Shared web config (persists cookies/logins between sessions)

enum SharedWebConfig {
    static let processPool = WKProcessPool()

    static func makeConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.processPool = processPool
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        return config
    }
}

struct WebView: UIViewRepresentable {
    let url: URL
    var linkId: String = ""
    var onYouTubeDetected: ((String) -> Void)? = nil

    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(onYouTubeDetected: onYouTubeDetected)
    }

    func makeUIView(context: Context) -> WKWebView {
        let c = context.coordinator
        c.linkId = linkId

        // Reuse a cached web view for this article — page is already loaded, scroll position intact
        if let cached = WebViewPool.shared.checkout(linkId: linkId) {
            cached.uiDelegate = c
            cached.navigationDelegate = c
            c.scrollObservation = cached.scrollView.observe(
                \.contentOffset, options: [.new]
            ) { [weak c] scrollView, _ in
                c?.schedulePositionSave(y: Double(scrollView.contentOffset.y))
            }
            return cached
        }

        let webView = WKWebView(frame: .zero, configuration: SharedWebConfig.makeConfiguration())
        webView.allowsBackForwardNavigationGestures = true
        webView.uiDelegate = c
        webView.navigationDelegate = c

        // KVO on contentOffset — Apple's recommended way to observe WKWebView scrolling
        // (setting scrollView.delegate directly is explicitly forbidden by Apple)
        c.scrollObservation = webView.scrollView.observe(
            \.contentOffset, options: [.new]
        ) { [weak c] scrollView, _ in
            c?.schedulePositionSave(y: Double(scrollView.contentOffset.y))
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url == nil {
            webView.load(URLRequest(url: url))
        }
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: WebViewCoordinator) {
        // Final authoritative save using the webView directly
        let y = Double(webView.scrollView.contentOffset.y)
        ScrollPositionStore.shared.save(linkId: coordinator.linkId, readerMode: false, y: y)
        coordinator.scrollObservation?.invalidate()
        coordinator.saveTimer?.invalidate()

        // Clear delegates before pooling so the old coordinator isn't retained
        webView.uiDelegate = nil
        webView.navigationDelegate = nil
        WebViewPool.shared.checkin(linkId: coordinator.linkId, webView: webView)
    }
}

/// Handles popups (target="_blank" links, OAuth windows) + scroll position persistence
class WebViewCoordinator: NSObject, WKUIDelegate, WKNavigationDelegate {
    var linkId: String = ""
    var scrollObservation: NSKeyValueObservation?
    var saveTimer: Timer?
    var onYouTubeDetected: ((String) -> Void)?

    init(onYouTubeDetected: ((String) -> Void)? = nil) {
        self.onYouTubeDetected = onYouTubeDetected
    }

    // Debounce scroll saves — fires 0.6 s after the user stops scrolling
    func schedulePositionSave(y: Double) {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { [weak self] _ in
            guard let self else { return }
            ScrollPositionStore.shared.save(linkId: self.linkId, readerMode: false, y: y)
        }
    }

    // Restore saved scroll position after page finishes loading.
    // Try immediately and again after 1.5 s for JS-rendered pages.
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let saved = ScrollPositionStore.shared.get(linkId: linkId, readerMode: false)
        guard saved > 50 else { return }
        webView.evaluateJavaScript("window.scrollTo(0, \(saved))", completionHandler: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak webView] in
            webView?.evaluateJavaScript("window.scrollTo(0, \(saved))", completionHandler: nil)
        }
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil || !navigationAction.targetFrame!.isMainFrame {
            if let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
        }
        return nil
    }

    func webViewDidClose(_ webView: WKWebView) {}

    // Intercept navigation to detect YouTube links
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        // Only intercept link clicks, not initial page loads
        guard navigationAction.navigationType == .linkActivated else {
            decisionHandler(.allow)
            return
        }

        // Check if this is a YouTube URL
        if let videoID = extractYouTubeID(url.absoluteString) {
            onYouTubeDetected?(videoID)
            decisionHandler(.cancel)
            return
        }

        // Allow all other links
        decisionHandler(.allow)
    }

    // Extract YouTube video ID from URL
    private func extractYouTubeID(_ urlString: String) -> String? {
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
}
