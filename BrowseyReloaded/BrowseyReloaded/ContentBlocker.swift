//
//  ContentBlocker.swift
//  BrowseyReloaded
//
//  Compiles and holds a WKContentRuleList for built-in ad blocking.
//  Rules are applied in WebView when creating the WKWebViewConfiguration.
//

import Foundation
internal import WebKit

/// Provides a compiled content rule list for ad blocking. Compiles when enabled; new tabs use it.
@Observable
final class ContentBlocker {
    static let shared = ContentBlocker()
    static let identifier = "BrowseyReloaded.AdBlock"

    private(set) var ruleList: WKContentRuleList?

    private init() {}

    /// Compile the built-in ad-block rules. Call when app launches or when user enables ad block.
    func compileIfNeeded(enabled: Bool) {
        guard enabled else {
            ruleList = nil
            return
        }
        let json = Self.adBlockRulesJSON
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: Self.identifier,
            encodedContentRuleList: json
        ) { [weak self] list, error in
            DispatchQueue.main.async {
                if let error = error {
                    NSLog("BrowseyReloaded: Content rule list compile failed: %@", error.localizedDescription)
                    self?.ruleList = nil
                    return
                }
                self?.ruleList = list
            }
        }
    }

    /// Expanded ad/tracker block list (url-filter is a regex; escape dots and special chars).
    private static var adBlockRulesJSON: String {
        let rules: [[String: Any]] = [
            // Google Ads
            ["trigger": ["url-filter": ".*doubleclick\\.net.*"], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*googlesyndication\\.com.*"], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*googleadservices\\.com.*"], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*adservice\\.google\\.com.*"], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*adservice\\.google\\.[a-z]+.*"], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*pagead2\\.googlesyndication\\.com.*"], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*googletagservices\\.com.*", "resource-type": ["script"]], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*googletagmanager\\.com/gtag.*", "resource-type": ["script"]], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*google-analytics\\.com.*", "resource-type": ["script"]], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*analytics\\.google\\.com.*"], "action": ["type": "block"]],
            // Social trackers
            ["trigger": ["url-filter": ".*facebook\\.com/tr.*"], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*connect\\.facebook\\.net.*", "resource-type": ["script"]], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*ads\\.twitter\\.com.*"], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*static\\.ads-twitter\\.com.*"], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*snap\\.licdn\\.com.*", "resource-type": ["script"]], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*ads\\.linkedin\\.com.*"], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*sc-static\\.net.*", "resource-type": ["script"]], "action": ["type": "block"]],
            // Ad networks
            ["trigger": ["url-filter": ".*\\.adsystem\\.com.*"], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*adnxs\\.com.*"], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*criteo\\.com.*"], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*criteo\\.net.*"], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*outbrain\\.com.*", "resource-type": ["script"]], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*taboola\\.com.*", "resource-type": ["script"]], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*moatads\\.com.*"], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*rubiconproject\\.com.*"], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*pubmatic\\.com.*"], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*openx\\.net.*"], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*openx\\.com.*"], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*smartadserver\\.com.*"], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*advertising\\.com.*"], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*adroll\\.com.*"], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*media\\.net.*", "resource-type": ["script"]], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*yieldmo\\.com.*", "resource-type": ["script"]], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*spotxchange\\.com.*"], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*bidswitch\\.net.*"], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*33across\\.com.*"], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*sharethrough\\.com.*", "resource-type": ["script"]], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*sovrn\\.com.*"], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*lijit\\.com.*"], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*adsrvr\\.org.*"], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*thetradedesk\\.com.*"], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*appnexus\\.com.*"], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*contextweb\\.com.*"], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*casalemedia\\.com.*"], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*indexexchange\\.com.*"], "action": ["type": "block"]],
            // Analytics & session recording
            ["trigger": ["url-filter": ".*scorecardresearch\\.com.*"], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*hotjar\\.com.*"], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*newrelic\\.com.*", "resource-type": ["script"]], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*mixpanel\\.com.*", "resource-type": ["script"]], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*segment\\.io.*", "resource-type": ["script"]], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*segment\\.com/analytics.*", "resource-type": ["script"]], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*amplitude\\.com.*", "resource-type": ["script"]], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*fullstory\\.com.*", "resource-type": ["script"]], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*mouseflow\\.com.*", "resource-type": ["script"]], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*logrocket\\.io.*", "resource-type": ["script"]], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*heap\\.io.*", "resource-type": ["script"]], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*clarity\\.ms.*", "resource-type": ["script"]], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*quantserve\\.com.*"], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*chartbeat\\.com.*", "resource-type": ["script"]], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*parsely\\.com.*", "resource-type": ["script"]], "action": ["type": "block"]],
            ["trigger": ["url-filter": ".*branch\\.io.*", "resource-type": ["script"]], "action": ["type": "block"]],
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: rules),
              let str = String(data: data, encoding: .utf8) else { return "[]" }
        return str
    }
}
