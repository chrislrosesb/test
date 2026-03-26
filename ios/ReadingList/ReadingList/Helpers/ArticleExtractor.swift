import WebKit
import Foundation

/// Fetches a URL in a hidden WKWebView and extracts the main article text via JS.
/// Handles JS-rendered pages, dynamic sites, and paywalled content gracefully.
@MainActor
final class ArticleExtractor: NSObject, WKNavigationDelegate {

    /// Convenience static entry point. Keeps the extractor alive for the duration of the async call.
    static func extract(from urlString: String) async throws -> String {
        let extractor = ArticleExtractor()
        return try await extractor.run(urlString: urlString)
    }

    private var webView: WKWebView?
    private var continuation: CheckedContinuation<String, Error>?

    // JS that finds the main content element and returns clean text, capped at 15 000 chars.
    private let extractJS = """
    (function() {
        var candidates = [
            'article',
            'main',
            '[role="main"]',
            '.post-content',
            '.article-content',
            '.entry-content',
            '.story-body',
            '.article-body',
            '.content-body',
            '.post-body'
        ];
        var el = null;
        for (var i = 0; i < candidates.length; i++) {
            var found = document.querySelector(candidates[i]);
            if (found && found.innerText && found.innerText.length > 300) {
                el = found;
                break;
            }
        }
        if (!el) {
            var maxLen = 0;
            var nodes = document.querySelectorAll('div, section');
            for (var j = 0; j < nodes.length; j++) {
                var node = nodes[j];
                var len = node.innerText ? node.innerText.length : 0;
                if (len > maxLen && len < 100000) { maxLen = len; el = node; }
            }
        }
        if (!el) el = document.body;
        var text = (el || document.body).innerText || '';
        text = text.replace(/\\n{3,}/g, '\\n\\n')
                   .replace(/[ \\t]{2,}/g, ' ')
                   .trim();
        return text.substring(0, 15000);
    })()
    """

    private func run(urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw ArticleExtractionError.invalidURL
        }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let wv = WKWebView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
            wv.navigationDelegate = self
            self.webView = wv
            let request = URLRequest(
                url: url,
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: 30
            )
            wv.load(request)
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript(extractJS) { [weak self] result, _ in
            guard let self, self.continuation != nil else { return }
            if let text = result as? String, text.count > 100 {
                self.continuation?.resume(returning: text)
            } else {
                self.continuation?.resume(throwing: ArticleExtractionError.extractionFailed)
            }
            self.continuation = nil
            self.webView = nil
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
        self.webView = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
        self.webView = nil
    }
}

enum ArticleExtractionError: LocalizedError {
    case invalidURL
    case extractionFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid article URL"
        case .extractionFailed: return "Could not extract article text — the page may be behind a paywall or require JavaScript"
        }
    }
}
