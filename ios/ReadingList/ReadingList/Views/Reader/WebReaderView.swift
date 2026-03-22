import SwiftUI
import WebKit

struct WebReaderView: View {
    let url: String
    let title: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let webURL = URL(string: url) {
                    WebView(url: webURL)
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        guard let webURL = URL(string: url) else { return }
                        UIApplication.shared.open(webURL)
                    } label: {
                        Image(systemName: "safari")
                    }
                }
            }
        }
    }
}

struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let req = URLRequest(url: url)
        if webView.url == nil {
            webView.load(req)
        }
    }
}
