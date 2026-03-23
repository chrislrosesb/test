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
    case system, serif, mono

    var label: String {
        switch self {
        case .system: return "System"
        case .serif: return "Serif"
        case .mono: return "Mono"
        }
    }

    var css: String {
        switch self {
        case .system: return "-apple-system, 'SF Pro Text', sans-serif"
        case .serif: return "Georgia, 'New York', serif"
        case .mono: return "'SF Mono', 'Courier New', monospace"
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

    private let fonts: [(ReaderFont, Font)] = [
        (.system, .body),
        (.serif, .custom("Georgia", size: 17)),
        (.mono, .system(.body, design: .monospaced))
    ]

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
                    fontRow(.system, preview: .body)
                    fontRow(.serif, preview: .custom("Georgia", size: 17))
                    fontRow(.mono, preview: .system(.body, design: .monospaced))
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

// MARK: - Reader Web View (Readability injection)

struct ReaderWebView: UIViewRepresentable {
    let url: URL
    let fontSize: Double
    let font: ReaderFont
    let theme: ReaderTheme
    let onFallback: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(fontSize: fontSize, font: font, theme: theme, onFallback: onFallback)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.scrollView.bounces = true
        context.coordinator.webView = webView
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.fontSize = fontSize
        context.coordinator.font = font
        context.coordinator.theme = theme
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var fontSize: Double
        var font: ReaderFont
        var theme: ReaderTheme
        let onFallback: () -> Void
        weak var webView: WKWebView?
        var hasInjected = false

        init(fontSize: Double, font: ReaderFont, theme: ReaderTheme, onFallback: @escaping () -> Void) {
            self.fontSize = fontSize
            self.font = font
            self.theme = theme
            self.onFallback = onFallback
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !hasInjected else { return }
            // Wait briefly for JS-rendered pages
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.extractAndRender(webView: webView)
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.onFallback() }
        }

        private func extractAndRender(webView: WKWebView) {
            let js = Self.extractionJS
            webView.evaluateJavaScript(js) { [weak self] result, error in
                guard let self else { return }
                guard let jsonString = result as? String,
                      let data = jsonString.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                      let content = json["content"],
                      !content.isEmpty else {
                    DispatchQueue.main.async { self.onFallback() }
                    return
                }
                let title = json["title"] ?? ""
                let html = self.buildHTML(title: title, content: content)
                DispatchQueue.main.async {
                    self.hasInjected = true
                    webView.loadHTMLString(html, baseURL: webView.url)
                }
            }
        }

        private func buildHTML(title: String, content: String) -> String {
            """
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
            h1.reader-title { font-size: 1.45em; line-height: 1.3; margin: 0 0 20px; }
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
            \(content)
            </body>
            </html>
            """
        }

        // Inline JS: strip noise, find main content, return JSON
        static let extractionJS = """
        (function() {
            try {
                // Remove noise elements
                var noiseSelectors = [
                    'script','style','noscript','nav','header','footer','aside',
                    '[class*="sidebar"]','[class*="navigation"]','[class*="menu-"]',
                    '[class*="header"]','[class*="footer"]','[class*="comments"]',
                    '[class*="advertisement"]','[class*="-ad-"]','[id*="sidebar"]',
                    '[id*="navigation"]','[id*="header"]','[id*="footer"]',
                    'iframe','.related','.recommended','[class*="social"]',
                    '[class*="share-"]','[class*="promo"]','[class*="cookie"]',
                    '[class*="subscribe"]','[class*="newsletter"]','[class*="popup"]'
                ];
                document.querySelectorAll(noiseSelectors.join(',')).forEach(function(el){el.remove();});

                // Find main content
                var selectors = [
                    '[itemprop="articleBody"]','article','[role="main"]','main',
                    '.post-content','.article-content','.entry-content',
                    '.article-body','.story-body','.post-body','#article-body',
                    '.content-body','.article__body','.ArticleBody',
                    '#content','.content','.post','.single-post'
                ];
                var content = null;
                for (var i = 0; i < selectors.length; i++) {
                    var el = document.querySelector(selectors[i]);
                    if (el && (el.innerText || '').trim().length > 150) {
                        content = el; break;
                    }
                }
                if (!content) content = document.body;

                // Remove inner noise
                var innerNoise = content.querySelectorAll(
                    'script,style,[class*="related"],[class*="recommend"],[class*="promo"],[class*="share"]'
                );
                innerNoise.forEach(function(el){el.remove();});

                var title = '';
                var h1 = document.querySelector('h1');
                if (h1) { title = h1.innerText.trim(); h1.remove(); }
                else { title = document.title; }

                return JSON.stringify({ title: title, content: content.innerHTML });
            } catch(e) {
                return JSON.stringify({ title: document.title, content: document.body.innerHTML });
            }
        })()
        """
    }
}

// MARK: - Full WebView (unchanged)

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

    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: SharedWebConfig.makeConfiguration())
        webView.allowsBackForwardNavigationGestures = true
        webView.uiDelegate = context.coordinator
        context.coordinator.parentWebView = webView
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url == nil {
            webView.load(URLRequest(url: url))
        }
    }
}

/// Handles popups (target="_blank" links, OAuth windows)
class WebViewCoordinator: NSObject, WKUIDelegate {
    weak var parentWebView: WKWebView?

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        // Load popup URLs in the same webview
        if navigationAction.targetFrame == nil || !navigationAction.targetFrame!.isMainFrame {
            if let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
        }
        return nil
    }

    func webViewDidClose(_ webView: WKWebView) {}
}
