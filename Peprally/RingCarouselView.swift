import SwiftUI
import WebKit

/// The onboarding ring carousel — the self-contained web component bundled
/// under Resources/ring, rendered in a non-interactive web view.
struct RingCarouselView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        // match the host background (the component reads --bg)
        let js = "document.documentElement.style.setProperty('--bg', '#ffffff');"
        config.userContentController.addUserScript(
            WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true))

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .white
        webView.scrollView.isScrollEnabled = false
        webView.isUserInteractionEnabled = false

        if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "ring") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
