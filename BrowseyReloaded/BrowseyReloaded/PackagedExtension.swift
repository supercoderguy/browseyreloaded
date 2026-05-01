//
//  PackagedExtension.swift
//  BrowseyReloaded
//
//  Minimal packaged extension loader — reads `manifest.json` from an
//  `Extensions/` folder in the app bundle and converts content scripts
//  into `WKUserScript` instances. Keeps a simple on/off state in
//  `UserDefaults` so bundled extensions can be toggled.
//

import Foundation
internal import WebKit

struct ExtensionManifest: Codable {
    var id: String?
    var name: String
    var version: String?
    var description: String?
    var manifest_version: Int?
    var permissions: [String]?
    var content_scripts: [ManifestContentScript]?
    var background: Background?
    var browser_specific_settings: BrowserSpecificSettings?
    var web_accessible_resources: [String]?

    struct Background: Codable {
        var scripts: [String]?
        var service_worker: String?
    }

    struct BrowserSpecificSettings: Codable {
        var gecko: Gecko?

        struct Gecko: Codable {
            var id: String?
        }
    }
}

struct ManifestContentScript: Codable {
    var matches: [String]?
    var exclude_matches: [String]?
    var js: [String]?
    var css: [String]?
    var run_at: String? // "document_start" or "document_end"
    var run_in_page_world: Bool?
}

@Observable
final class PackagedExtensionStore {
    static let shared = PackagedExtensionStore()
    private static let enabledKey = "BrowseyReloaded.PackagedExtensionsState"

    struct PackagedExtension: Identifiable {
        var id: String
        var name: String
        var manifest: ExtensionManifest
        var folderURL: URL?
        var isEnabled: Bool
    }

    private(set) var extensions: [PackagedExtension] = [] {
        didSet { saveEnabledStates() }
    }

    private var enabledStates: [String: Bool] = [:]

    private init() {
        loadEnabledStates()
        discover()
    }

    func reload() {
        loadEnabledStates()
        discover()
    }

    private func discover() {
        var out: [PackagedExtension] = []
        let fm = FileManager.default
        guard let resourceURL = Bundle.main.resourceURL else { extensions = []; return }
        let extRoot = resourceURL.appendingPathComponent("Extensions", isDirectory: true)
        guard fm.fileExists(atPath: extRoot.path) else { extensions = []; return }
        guard let subdirs = try? fm.contentsOfDirectory(at: extRoot, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else { extensions = []; return }
        for dir in subdirs where dir.hasDirectoryPath {
            let manifestURL = dir.appendingPathComponent("manifest.json")
            guard fm.fileExists(atPath: manifestURL.path) else { continue }
            if let data = try? Data(contentsOf: manifestURL), let manifest = try? JSONDecoder().decode(ExtensionManifest.self, from: data) {
                let idStr = manifest.id ?? manifest.browser_specific_settings?.gecko?.id ?? dir.lastPathComponent
                let name = manifest.name
                let enabled = enabledStates[idStr] ?? true
                out.append(PackagedExtension(id: idStr, name: name, manifest: manifest, folderURL: dir, isEnabled: enabled))
            }
        }
        extensions = out
    }

    func setEnabled(_ id: String, _ enabled: Bool) {
        if let i = extensions.firstIndex(where: { $0.id == id }) {
            extensions[i].isEnabled = enabled
            saveEnabledStates()
        }
    }

    func buildWKUserScripts() -> [WKUserScript] {
        var out: [WKUserScript] = []
        var needsIsolated = false
        var needsPage = false
        for ext in extensions where ext.isEnabled {
            guard let scripts = ext.manifest.content_scripts else { continue }
            for cs in scripts {
                if cs.run_in_page_world == true { needsPage = true } else { needsIsolated = true }
            }
        }
        if needsIsolated {
            out.append(Self.bootstrap(in: .defaultClient, injectionTime: .atDocumentStart))
        }
        if needsPage {
            out.append(Self.bootstrap(in: .page, injectionTime: .atDocumentStart))
        }

        for ext in extensions where ext.isEnabled {
            guard let scripts = ext.manifest.content_scripts else { continue }
            for cs in scripts {
                let injection: WKUserScriptInjectionTime = (cs.run_at == "document_start") ? .atDocumentStart : .atDocumentEnd
                let world: WKContentWorld = (cs.run_in_page_world == true) ? .page : .defaultClient
                let matchesJSON = PackagedExtensionStore.jsonArrayString(cs.matches ?? [])
                let excludesJSON = PackagedExtensionStore.jsonArrayString(cs.exclude_matches ?? [])
                var jsCombined = ""
                var cssCombined = ""
                if let jsFiles = cs.js {
                    for jsFile in jsFiles {
                        if let folder = ext.folderURL {
                            let fileURL = folder.appendingPathComponent(jsFile)
                            if let s = try? String(contentsOf: fileURL, encoding: .utf8) {
                                jsCombined += "\n" + s
                            }
                        }
                    }
                }
                if let cssFiles = cs.css {
                    for cssFile in cssFiles {
                        if let folder = ext.folderURL {
                            let fileURL = folder.appendingPathComponent(cssFile)
                            if let s = try? String(contentsOf: fileURL, encoding: .utf8) {
                                cssCombined += "\n" + s
                            }
                        }
                    }
                }
                let jsB64 = Data(jsCombined.utf8).base64EncodedString()
                let cssB64 = Data(cssCombined.utf8).base64EncodedString()
                                let extId = ext.id
                                let extIdEscaped = extId.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
                                let source = """
                (function() {
                                    var __id = '\(extIdEscaped)';
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
                  } catch (e) { console.error('[Browsey ext]', __id, e); }
                })();
                """
                out.append(WKUserScript(source: source, injectionTime: injection, forMainFrameOnly: false, in: world))
            }
        }
        return out
    }

    private static func bootstrap(in world: WKContentWorld, injectionTime: WKUserScriptInjectionTime) -> WKUserScript {
        WKUserScript(source: bootstrapJavaScript, injectionTime: injectionTime, forMainFrameOnly: false, in: world)
    }

    private static func jsonArrayString(_ arr: [String]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: arr),
              let s = String(data: data, encoding: .utf8) else { return "[]" }
        return s
    }

    private func saveEnabledStates() {
        var dict: [String: Bool] = [:]
        for ext in extensions {
            dict[ext.id] = ext.isEnabled
        }
        UserDefaults.standard.set(dict, forKey: Self.enabledKey)
    }

    private func loadEnabledStates() {
        if let dict = UserDefaults.standard.dictionary(forKey: Self.enabledKey) as? [String: Bool] {
            enabledStates = dict
        } else {
            enabledStates = [:]
        }
    }

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
          else if (c === '\\' || c === '.' || c === '^' || c === '$' || c === '(' || c === ')' || c === '+' || c === '?' || c === '[' || c === ']' || c === '{' || c === '}' || c === '|') esc += '\\' + c;
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
