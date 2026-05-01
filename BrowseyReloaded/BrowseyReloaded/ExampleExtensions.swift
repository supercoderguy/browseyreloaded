//
//  ExampleExtensions.swift
//  BrowseyReloaded
//
//  Bundled example user scripts (not ad blocking — that’s built into the app).
//

import Foundation

enum ExampleExtensions {
    struct CatalogEntry: Identifiable {
        let id: String
        let name: String
        let summary: String
        /// Produces a fresh `UserScript` with a new id each time (safe to add multiple copies).
        let make: () -> UserScript
    }

    static let catalog: [CatalogEntry] = [
        CatalogEntry(
            id: "reading-width",
            name: "Comfortable reading width",
            summary: "Narrower column for main/article content and calmer line height."
        ) {
            UserScript(
                name: "Example: Comfortable reading width",
                script: "",
                css: """
                main, article, [role="main"] {
                  max-width: 52rem !important;
                  margin-left: auto !important;
                  margin-right: auto !important;
                  padding-left: 1rem !important;
                  padding-right: 1rem !important;
                }
                main p, article p {
                  line-height: 1.65 !important;
                  max-width: 100%;
                }
                """,
                matchPatterns: ["*://*/*"],
                injectAtDocumentStart: false,
                isEnabled: true,
                runInPageWorld: false
            )
        },
        CatalogEntry(
            id: "same-tab-links",
            name: "Open new-tab links in this tab",
            summary: "Clears target=_blank so more links stay in the same tab."
        ) {
            UserScript(
                name: "Example: Same-tab links",
                script: """
                (function () {
                  function stripTargets(root) {
                    root.querySelectorAll('a[target="_blank"]').forEach(function (a) {
                      a.removeAttribute('target');
                      var rel = (a.getAttribute('rel') || '').split(/\\s+/).filter(function (x) {
                        return x !== 'noopener' && x !== 'noreferrer';
                      });
                      if (rel.length) a.setAttribute('rel', rel.join(' '));
                      else a.removeAttribute('rel');
                    });
                  }
                  stripTargets(document);
                  var obs = new MutationObserver(function (muts) {
                    muts.forEach(function (m) {
                      m.addedNodes.forEach(function (n) {
                        if (n.nodeType === 1) stripTargets(n);
                      });
                    });
                  });
                  obs.observe(document.documentElement, { childList: true, subtree: true });
                })();
                """,
                css: "",
                matchPatterns: ["*://*/*"],
                injectAtDocumentStart: false,
                isEnabled: true,
                runInPageWorld: false
            )
        },
        CatalogEntry(
            id: "jk-scroll",
            name: "Keyboard: J / K to scroll",
            summary: "Vim-style scroll (disabled while typing in inputs)."
        ) {
            UserScript(
                name: "Example: J/K scroll",
                script: """
                (function () {
                  if (document.documentElement.getAttribute('data-browsey-jk') === '1') return;
                  document.documentElement.setAttribute('data-browsey-jk', '1');
                  document.addEventListener('keydown', function (e) {
                    if (e.ctrlKey || e.metaKey || e.altKey) return;
                    var t = e.target;
                    if (t && t.nodeType !== 1) t = t.parentElement;
                    if (!t) return;
                    if (t.closest && t.closest('input, textarea, select, [contenteditable="true"]')) return;
                    var step = Math.round(window.innerHeight * 0.35);
                    if (e.key === 'j' || e.key === 'J') { window.scrollBy({ top: step, left: 0, behavior: 'auto' }); e.preventDefault(); }
                    if (e.key === 'k' || e.key === 'K') { window.scrollBy({ top: -step, left: 0, behavior: 'auto' }); e.preventDefault(); }
                  }, true);
                })();
                """,
                css: "",
                matchPatterns: ["*://*/*"],
                injectAtDocumentStart: false,
                isEnabled: true,
                runInPageWorld: false
            )
        },
        CatalogEntry(
            id: "focus-rings",
            name: "Visible keyboard focus outlines",
            summary: "Strong :focus-visible rings for keyboard navigation."
        ) {
            UserScript(
                name: "Example: Visible focus outlines",
                script: "",
                css: """
                :focus-visible {
                  outline: 2px solid #2563eb !important;
                  outline-offset: 2px !important;
                }
                @media (prefers-color-scheme: dark) {
                  :focus-visible {
                    outline-color: #93c5fd !important;
                  }
                }
                """,
                matchPatterns: ["*://*/*"],
                injectAtDocumentStart: false,
                isEnabled: true,
                runInPageWorld: false
            )
        },
        CatalogEntry(
            id: "native-ping",
            name: "Notify app when page loads",
            summary: "Sends title and URL to Swift via browser.runtime.sendNativeMessage."
        ) {
            let extId = UUID()
            return UserScript(
                id: extId,
                name: "Example: Page info to app",
                script: """
                (function () {
                  if (typeof browser === 'undefined' || !browser.runtime || !browser.runtime.sendNativeMessage) return;
                  browser.runtime.sendNativeMessage("\(extId.uuidString)", {
                    kind: "pageInfo",
                    title: document.title,
                    href: location.href
                  });
                })();
                """,
                css: "",
                matchPatterns: ["*://*/*"],
                injectAtDocumentStart: false,
                isEnabled: true,
                runInPageWorld: false
            )
        },
        CatalogEntry(
            id: "code-font",
            name: "Nicer code blocks",
            summary: "System monospace stack for pre/code/kbd."
        ) {
            UserScript(
                name: "Example: Code block font",
                script: "",
                css: """
                pre, code, kbd, samp {
                  font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace !important;
                  font-size: 0.92em !important;
                }
                pre {
                  padding: 0.75rem 1rem !important;
                  border-radius: 6px !important;
                  overflow-x: auto !important;
                }
                """,
                matchPatterns: ["*://*/*"],
                injectAtDocumentStart: false,
                isEnabled: true,
                runInPageWorld: false
            )
        },
    ]
}
