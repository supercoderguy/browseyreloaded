//
//  UserScript.swift
//  BrowseyReloaded
//
//  User scripts with URL patterns, optional CSS, content world, and a native bridge.
//

import Foundation
internal import WebKit

struct UserScript: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    /// Injected JavaScript (optional if only CSS is used).
    var script: String
    /// Optional user stylesheet (injected as a `<style>` when the URL matches).
    var css: String
    /// Chrome-style match patterns; empty means `*://*/*` (all URLs).
    var matchPatterns: [String]
    /// If any pattern matches, the script does not run.
    var excludePatterns: [String]
    var injectAtDocumentStart: Bool
    var isEnabled: Bool
    /// When false (default), runs in WebKit’s isolated content world. When true, runs in the page’s JS world (same as site scripts).
    var runInPageWorld: Bool

    init(
        id: UUID = UUID(),
        name: String = "Script",
        script: String = "",
        css: String = "",
        matchPatterns: [String] = [],
        excludePatterns: [String] = [],
        injectAtDocumentStart: Bool = false,
        isEnabled: Bool = true,
        runInPageWorld: Bool = false
    ) {
        self.id = id
        self.name = name
        self.script = script
        self.css = css
        self.matchPatterns = matchPatterns
        self.excludePatterns = excludePatterns
        self.injectAtDocumentStart = injectAtDocumentStart
        self.isEnabled = isEnabled
        self.runInPageWorld = runInPageWorld
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, script, css, matchPatterns, excludePatterns
        case injectAtDocumentStart, isEnabled, runInPageWorld
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Script"
        script = try c.decodeIfPresent(String.self, forKey: .script) ?? ""
        css = try c.decodeIfPresent(String.self, forKey: .css) ?? ""
        matchPatterns = try c.decodeIfPresent([String].self, forKey: .matchPatterns) ?? []
        excludePatterns = try c.decodeIfPresent([String].self, forKey: .excludePatterns) ?? []
        injectAtDocumentStart = try c.decodeIfPresent(Bool.self, forKey: .injectAtDocumentStart) ?? false
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        runInPageWorld = try c.decodeIfPresent(Bool.self, forKey: .runInPageWorld) ?? false
    }

    /// Whether this script would run for `url` (same rules as the injected JavaScript matcher).
    func shouldRun(on url: URL) -> Bool {
        ExtensionMatchPattern.shouldRunScript(url: url, matchPatterns: matchPatterns, excludePatterns: excludePatterns)
    }
}

/// Persists user scripts to UserDefaults and exposes them for WebView configuration.
@Observable
final class UserScriptStore {
    static let shared = UserScriptStore()
    private static let key = "BrowseyReloaded.UserScripts"

    var scripts: [UserScript] = [] {
        didSet { save() }
    }

    private init() {
        load()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.key),
              let decoded = try? JSONDecoder().decode([UserScript].self, from: data) else { return }
        scripts = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(scripts) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }

    func add(_ script: UserScript) {
        scripts.append(script)
    }

    func remove(_ script: UserScript) {
        scripts.removeAll { $0.id == script.id }
    }

    func update(_ script: UserScript) {
        if let i = scripts.firstIndex(where: { $0.id == script.id }) {
            scripts[i] = script
        }
    }

    /// Build WKUserScript entries for enabled scripts (for WKWebViewConfiguration).
    func buildWKUserScripts() -> [WKUserScript] {
        let enabled = scripts.filter(\.isEnabled).filter { script in
            let hasJS = !script.script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let hasCSS = !script.css.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return hasJS || hasCSS
        }

        var out: [WKUserScript] = []
        let needsIsolated = enabled.contains { !$0.runInPageWorld }
        let needsPage = enabled.contains { $0.runInPageWorld }

        if needsIsolated {
            out.append(Self.bootstrap(in: .defaultClient, injectionTime: .atDocumentStart))
        }
        if needsPage {
            out.append(Self.bootstrap(in: .page, injectionTime: .atDocumentStart))
        }

        for script in enabled where !script.runInPageWorld {
            out.append(Self.wrappedUserScript(script, world: .defaultClient))
        }
        for script in enabled where script.runInPageWorld {
            out.append(Self.wrappedUserScript(script, world: .page))
        }

        return out
    }

    private static func bootstrap(in world: WKContentWorld, injectionTime: WKUserScriptInjectionTime) -> WKUserScript {
        WKUserScript(
            source: Self.bootstrapJavaScript,
            injectionTime: injectionTime,
            forMainFrameOnly: false,
            in: world
        )
    }

    private static func wrappedUserScript(_ script: UserScript, world: WKContentWorld) -> WKUserScript {
        let injectionTime: WKUserScriptInjectionTime = script.injectAtDocumentStart ? .atDocumentStart : .atDocumentEnd
        let matchesJSON = jsonArrayString(script.matchPatterns)
        let excludesJSON = jsonArrayString(script.excludePatterns)
        let jsB64 = Data(script.script.utf8).base64EncodedString()
        let cssB64 = Data(script.css.utf8).base64EncodedString()
        let id = script.id.uuidString
        let source = """
        (function() {
          var __id = '\(id)';
          var __matches = \(matchesJSON);
          var __excludes = \(excludesJSON);
          var __jsB64 = '\(jsB64)';
          var __cssB64 = '\(cssB64)';
          if (typeof window.__browseyMatch !== 'function' || !window.__browseyMatch(location.href, __matches, __excludes)) return;
          try {
            if (__cssB64.length) {
              var css = atob(__cssB64);
              var st = document.createElement('style');
              st.setAttribute('data-browsey-extension', __id);
              st.textContent = css;
              (document.head || document.documentElement).appendChild(st);
            }
            if (__jsB64.length) {
              var code = atob(__jsB64);
              (function() { eval(code); })();
            }
          } catch (e) { console.error('[Browsey]', __id, e); }
        })();
        """
        return WKUserScript(
            source: source,
            injectionTime: injectionTime,
            forMainFrameOnly: false,
            in: world
        )
    }

    private static func jsonArrayString(_ arr: [String]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: arr),
              let s = String(data: data, encoding: .utf8) else { return "[]" }
        return s
    }

    /// Shared bootstrap: URL matching + `browser.runtime.sendNativeMessage(extensionId, data)`.
    private static let bootstrapJavaScript = """
    (function() {
      'use strict';
      if (window.__browseyMatch) return;
      function parsePattern(p) {
        var i = p.indexOf('://');
        if (i < 0) return null;
        var scheme = p.slice(0, i);
        var rest = p.slice(i + 3);
        var j = rest.indexOf('/');
        var host = j < 0 ? rest : rest.slice(0, j);
        var path = j < 0 ? '/*' : rest.slice(j);
        if (!path.length) path = '/';
        return { scheme: scheme, host: host, path: path };
      }
      function hostMatch(hostname, pattern) {
        if (pattern === '*') return true;
        if (pattern.indexOf('*.') === 0) {
          var suffix = pattern.slice(2);
          return hostname === suffix || (hostname.length > suffix.length && hostname.slice(-suffix.length - 1) === '.' + suffix);
        }
        return hostname === pattern;
      }
      function pathMatch(path, pattern) {
        if (pattern === '/*') return true;
        var esc = '';
        for (var k = 0; k < pattern.length; k++) {
          var c = pattern[k];
          if (c === '*') esc += '.*';
          else if (c === '\\\\' || c === '.' || c === '^' || c === '$' || c === '(' || c === ')' || c === '+' || c === '?' || c === '[' || c === ']' || c === '{' || c === '}' || c === '|') esc += '\\\\' + c;
          else esc += c;
        }
        return new RegExp('^' + esc + '$').test(path);
      }
      window.__browseyMatch = function(urlStr, patterns, excludes) {
        function one(p) {
          try {
            var u = new URL(urlStr);
            var pp = parsePattern(p);
            if (!pp) return false;
            if (pp.scheme !== '*' && u.protocol !== pp.scheme + ':') return false;
            var hn = u.hostname.toLowerCase();
            var ph = pp.host.toLowerCase();
            if (!hostMatch(hn, ph)) return false;
            var up = u.pathname + (u.search || '');
            return pathMatch(up, pp.path);
          } catch (e) { return false; }
        }
        var plist = (patterns && patterns.length) ? patterns : ['*://*/*'];
        if (!plist.some(one)) return false;
        if (excludes && excludes.length && excludes.some(one)) return false;
        return true;
      };
      window.browser = window.browser || {};
      window.browser.runtime = window.browser.runtime || {};
      window.browser.runtime.sendNativeMessage = function(extensionId, payload) {
        try {
          window.webkit.messageHandlers.browseyNative.postMessage({ extensionId: extensionId, data: payload });
        } catch (e) { console.error('[Browsey] native bridge', e); }
      };
    })();
    """
}
