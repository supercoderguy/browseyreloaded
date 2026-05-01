//
//  WebView.swift
//  BrowseyReloaded
//
//  Created by Jacob Ferrari on 8/2/2026.
//

import SwiftUI
internal import WebKit

/// Shared store for WebView navigation - allows toolbar to control the web view
@Observable
final class WebViewStore: WebEngineStore {
    weak var webView: WKWebView?

    func goBack() { webView?.goBack() }
    func goForward() { webView?.goForward() }
    func reload() { webView?.reload() }
    func load(_ url: URL) { webView?.load(URLRequest(url: url)) }
}

struct WebView: NSViewRepresentable {
    let initialURL: URL?
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var isLoading: Bool
    @Binding var currentURL: URL?
    @Binding var pageTitle: String
    var webViewStore: WebViewStore
    var onPageLoad: () -> Void
    var customUserAgent: String? = nil

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        
        let settings = BrowserSettings.shared
        config.preferences.setValue(settings.developerExtrasEnabled, forKey: "developerExtrasEnabled")
        // config.preferences.javaScriptEnabled = settings.javaScriptEnabled
        config.preferences.javaScriptCanOpenWindowsAutomatically = settings.javaScriptCanOpenWindows
        // config.preferences.plugInsEnabled = settings.plugInsEnabled
        config.preferences.minimumFontSize = CGFloat(settings.minimumFontSize)
        
        if let ruleList = ContentBlocker.shared.ruleList {
            config.userContentController.add(ruleList)
        }
        for script in UserScriptStore.shared.buildWKUserScripts() {
            config.userContentController.addUserScript(script)
        }
        for script in PackagedExtensionStore.shared.buildWKUserScripts() {
            config.userContentController.addUserScript(script)
        }
        config.userContentController.add(context.coordinator, name: "browseyNative")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = settings.javaScriptEnabled
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = settings.allowsBackForwardGestures
        webViewStore.webView = webView

        let ua = settings.userAgentOverride.isEmpty ? (customUserAgent ?? settings.defaultUserAgent) : settings.userAgentOverride
        webView.customUserAgent = ua

        webView.setMagnification(settings.defaultZoom, centeredAt: .zero)

        if let url = initialURL {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // No loading here — only load via WebViewStore.load() or initial load in makeNSView.
        // This prevents any SwiftUI-driven load from overwriting in-page navigation.
        applyLiveSettings(to: webView)
    }

    /// Apply settings that can be updated on existing WebViews without recreating them.
    private func applyLiveSettings(to webView: WKWebView) {
        let settings = BrowserSettings.shared

        // JavaScript enabled/disabled
        let jsEnabled = settings.javaScriptEnabled
        if webView.configuration.defaultWebpagePreferences.allowsContentJavaScript != jsEnabled {
            webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = jsEnabled
        }

        // Back/forward gestures
        if webView.allowsBackForwardNavigationGestures != settings.allowsBackForwardGestures {
            webView.allowsBackForwardNavigationGestures = settings.allowsBackForwardGestures
        }

        // User agent
        let ua = settings.userAgentOverride.isEmpty
            ? (customUserAgent ?? settings.defaultUserAgent)
            : settings.userAgentOverride
        if webView.customUserAgent != ua {
            webView.customUserAgent = ua
        }

        // Zoom — only apply if meaningfully different to avoid jitter
        let targetZoom = settings.defaultZoom
        if abs(webView.magnification - targetZoom) > 0.01 {
            webView.setMagnification(targetZoom, centeredAt: .zero)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "browseyNative" else { return }
            if let body = message.body as? [String: Any],
               let extIdStr = body["extensionId"] as? String {
                ExtensionNativeMessageBridge.shared.append(extensionId: extIdStr, payload: body["data"])
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.canGoBack = webView.canGoBack
            parent.canGoForward = webView.canGoForward
            parent.currentURL = webView.url
            parent.pageTitle = webView.title ?? "New Tab"
            parent.onPageLoad()
            DispatchQueue.main.async {
                webView.window?.makeFirstResponder(webView)
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if let httpResp = navigationResponse.response as? HTTPURLResponse {
                var headers: [String: String] = [:]
                for (k, v) in httpResp.allHeaderFields {
                    if let ks = k as? String, let vs = v as? String {
                        headers[ks.lowercased()] = vs
                    }
                }
                if let cd = headers["content-disposition"], cd.lowercased().contains("attachment") {
                    decisionHandler(.cancel)
                    if let url = httpResp.url {
                        var suggested: String? = nil
                        if let r = cd.range(of: "filename=\"") {
                            let start = cd.index(r.upperBound, offsetBy: 0)
                            if let end = cd[start...].firstIndex(of: "\"") {
                                suggested = String(cd[start..<end])
                            }
                        } else if let r = cd.range(of: "filename=") {
                            let start = cd.index(r.upperBound, offsetBy: 0)
                            suggested = String(cd[start...]).trimmingCharacters(in: CharacterSet(charactersIn: " \""))
                        }
                        DownloadManager.shared.startDownload(from: url, suggestedFilename: suggested)
                    }
                    return
                }
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if BrowserSettings.shared.blockPopups { return nil }
            return nil
        }
    }
}

