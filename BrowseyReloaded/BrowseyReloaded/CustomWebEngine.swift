//
//  CustomWebEngine.swift
//  BrowseyReloaded
//
//  Minimal custom web engine: fetches HTML, parses structure, renders in SwiftUI.
//

import SwiftUI
import JavaScriptCore

actor PageCache {
    static let shared = PageCache()
    private var cache: [URL: ParsedHTML] = [:]
    private let maxCacheSize = 50 // Keep max 50 pages in memory

    func get(_ url: URL) -> ParsedHTML? {
        cache[url]
    }

    func set(_ url: URL, content: ParsedHTML) {
        // Trim cache if it gets too large
        if cache.count >= maxCacheSize {
            // Remove least recently accessed (FIFO for simplicity)
            if let oldestKey = cache.keys.first {
                cache.removeValue(forKey: oldestKey)
            }
        }
        cache[url] = content
    }
    
    func clearCache() {
        cache.removeAll()
    }
}

// MARK: - Custom Engine Store

@Observable
final class CustomEngineStore: WebEngineStore {
    var currentURL: URL?
    var pageTitle: String = "New Tab"
    var isLoading: Bool = false
    var canGoBack: Bool { !historyBack.isEmpty }
    var canGoForward: Bool { !historyForward.isEmpty }
    var errorMessage: String?
    var parsedContent: ParsedHTML?
    private var jsContext: JSContext?
    private var currentHTMLString: String = ""

    private var historyBack: [URL] = []
    private var historyForward: [URL] = []
    private var currentTask: Task<Void, Never>?
    
    deinit {
        currentTask?.cancel()
    }

    func load(_ url: URL) {
        guard url.scheme == "http" || url.scheme == "https" else {
            errorMessage = "Custom engine only supports http/https URLs."
            return
        }
        if let current = currentURL {
            historyBack.append(current)
        }
        historyForward.removeAll()
        currentURL = url
        errorMessage = nil
        fetchAndParse(url: url)
    }

    func goBack() {
        guard let url = historyBack.popLast() else { return }
        if let current = currentURL {
            historyForward.append(current)
        }
        currentURL = url
        errorMessage = nil
        fetchAndParse(url: url)
    }

    func goForward() {
        guard let url = historyForward.popLast() else { return }
        if let current = currentURL {
            historyBack.append(current)
        }
        currentURL = url
        errorMessage = nil
        fetchAndParse(url: url)
    }

    func reload() {
        guard let url = currentURL else { return }
        errorMessage = nil
        fetchAndParse(url: url)
    }

    private func fetchAndParse(url: URL) {
        isLoading = true
        parsedContent = nil
        pageTitle = url.host ?? "Loading..."
        
        // Cancel previous request
        currentTask?.cancel()

        Task {
            // Check cache first
            if let cached = await PageCache.shared.get(url) {
                try? Task.checkCancellation()
                await MainActor.run {
                    self.parsedContent = cached
                    self.pageTitle = cached.title
                    self.isLoading = false
                }
                return
            }
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 13_5) BrowseyReloaded/0.1", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15.0

        currentTask = Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                try Task.checkCancellation()
                
                guard let http = response as? HTTPURLResponse else {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = "Invalid response from server"
                    }
                    return
                }
                
                guard (200..<400).contains(http.statusCode) else {
                    let statusMessage = HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
                    await MainActor.run {
                        isLoading = false
                        errorMessage = "Error \(http.statusCode): \(statusMessage)"
                    }
                    return
                }
                
                var html = String(data: data, encoding: .utf8) ?? ""
                self.currentHTMLString = html
                try Task.checkCancellation()

                // Hard cap to prevent freezing on massive pages
                if html.count > 500_000 {
                    html = String(html.prefix(500_000))
                }
                
                // Parse off main thread to avoid freezing UI
                var parsed = await Task.detached(priority: .utility) {
                    await SimpleHTMLParser.parse(html, baseURL: url)
                }.value
                
                try Task.checkCancellation()

                // Load external stylesheets referenced by the page
                if !parsed.externalStyleURLs.isEmpty {
                    let externalRules = await fetchStylesheetRules(from: parsed.externalStyleURLs)
                    if !externalRules.isEmpty {
                        parsed = ParsedHTML(
                            title: parsed.title,
                            domRoot: parsed.domRoot,
                            cssRules: parsed.cssRules + externalRules,
                            externalStyleURLs: parsed.externalStyleURLs
                        )
                    }
                }

                try Task.checkCancellation()

                // Setup JS engine and execute inline scripts
                setupJavaScriptContext(for: url)
                executeScripts(in: html)

                await PageCache.shared.set(url, content: parsed)
                await MainActor.run {
                    self.isLoading = false
                    self.parsedContent = parsed
                    self.pageTitle = parsed.title
                }
            } catch is CancellationError {
                // Request was cancelled, don't update UI
                return
            } catch {
                let errorDesc = error.localizedDescription
                #if DEBUG
                print("CustomWebEngine load error:", errorDesc)
                #endif
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to load: \(errorDesc)"
                }
            }
        }
    }

    private func setupJavaScriptContext(for url: URL) {
        let context = JSContext()
        context?.exceptionHandler = { _, exception in
            #if DEBUG
            print("JS Error:", exception?.toString() ?? "unknown")
            #endif
        }

        // Basic console.log support
        let consoleLog: @convention(block) (String) -> Void = { message in
            #if DEBUG
            print("JS console.log:", message)
            #endif
        }

        let console = JSValue(newObjectIn: context)
        console?.setObject(consoleLog, forKeyedSubscript: "log" as NSString)
        context?.setObject(console, forKeyedSubscript: "console" as NSString)

        // Expose minimal location object
        let location = JSValue(newObjectIn: context)
        location?.setObject(url.absoluteString, forKeyedSubscript: "href" as NSString)
        context?.setObject(location, forKeyedSubscript: "location" as NSString)

        self.jsContext = context
        exposeDOMBridge()
    }

    private func exposeDOMBridge() {
        guard let context = jsContext else { return }

        let document = JSValue(newObjectIn: context)
        
        // Inserted location object definition here
        let location = JSValue(newObjectIn: context)
        location?.setObject(self.currentURL?.absoluteString ?? "about:blank", forKeyedSubscript: "href" as NSString)
        context.setObject(location, forKeyedSubscript: "location" as NSString)

        // document.body.innerHTML getter/setter
        let getInnerHTML: @convention(block) () -> String = { [weak self] in
            return self?.currentHTMLString ?? ""
        }

        let setInnerHTML: @convention(block) (String) -> Void = { [weak self] newHTML in
            guard let self else { return }
            Task.detached(priority: .utility) {
                let parsed = await SimpleHTMLParser.parse(newHTML, baseURL: self.currentURL ?? URL(string: "about:blank")!)
                await MainActor.run {
                    self.parsedContent = parsed
                }
            }
        }

        let documentWrite: @convention(block) (String) -> Void = { [weak self] text in
            guard let self else { return }
            self.currentHTMLString += text
            Task.detached(priority: .utility) {
                let parsed = await SimpleHTMLParser.parse(self.currentHTMLString, baseURL: self.currentURL ?? URL(string: "about:blank")!)
                await MainActor.run {
                    self.parsedContent = parsed
                }
            }
        }

        let documentWriteln: @convention(block) (String) -> Void = { text in
            documentWrite(text + "\n")
        }

        document?.setObject(getInnerHTML, forKeyedSubscript: "_getInnerHTML" as NSString)
        document?.setObject(setInnerHTML, forKeyedSubscript: "_setInnerHTML" as NSString)
        document?.setObject(documentWrite, forKeyedSubscript: "write" as NSString)
        document?.setObject(documentWriteln, forKeyedSubscript: "writeln" as NSString)

        let body = JSValue(newObjectIn: context)
        body?.setObject({ getInnerHTML() }, forKeyedSubscript: "getInnerHTML" as NSString)
        body?.setObject({ (value: String) in setInnerHTML(value) }, forKeyedSubscript: "setInnerHTML" as NSString)
        document?.setObject(body, forKeyedSubscript: "body" as NSString)
        context.setObject(document, forKeyedSubscript: "document" as NSString)

        // setTimeout stub
        let setTimeout: @convention(block) (JSValue, Double) -> Void = { callback, delay in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay / 1000.0) {
                callback.call(withArguments: [])
            }
        }
        context.setObject(setTimeout, forKeyedSubscript: "setTimeout" as NSString)
        
        // Basic window object support
        let window = JSValue(newObjectIn: context)
        window?.setObject(location, forKeyedSubscript: "location" as NSString)
        window?.setObject(setTimeout, forKeyedSubscript: "setTimeout" as NSString)
        context.setObject(window, forKeyedSubscript: "window" as NSString)
    }

    private func executeScripts(in html: String) {
        guard let context = jsContext else { return }

        let pattern = #"<script[^>]*>([\s\S]*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return }

        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        for match in matches {
            if let range = Range(match.range(at: 1), in: html) {
                let script = String(html[range])
                context.evaluateScript(script)
            }
        }
    }

    private func fetchStylesheetRules(from urls: [URL]) async -> [CSSRule] {
        var rules: [CSSRule] = []
        for url in urls {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let http = response as? HTTPURLResponse,
                      (200..<400).contains(http.statusCode),
                      let css = String(data: data, encoding: .utf8) else {
                    continue
                }
                rules.append(contentsOf: CSSEngine.parseCSS(css))
            } catch {
                #if DEBUG
                print("Failed to load stylesheet: \(url) - \(error)")
                #endif
            }
        }
        return rules
    }
}

// MARK: - HTML Model

struct ParsedHTML {
    let title: String

    // DOM root node representing body content
    let domRoot: DOMNode?

    // Parsed CSS rules from <style> blocks and external stylesheets
    let cssRules: [CSSRule]

    // External stylesheet URLs discovered in the page
    let externalStyleURLs: [URL]
}

// MARK: - DOM Tree Model

final class DOMNode: Identifiable {
    enum NodeType {
        case element(tag: String, attributes: [String: String])
        case text(String)
    }

    let id = UUID()
    var type: NodeType
    weak var parent: DOMNode?
    var children: [DOMNode] = []

    init(type: NodeType) {
        self.type = type
    }

    func appendChild(_ node: DOMNode) {
        node.parent = self
        children.append(node)
    }
}

// MARK: - CSS Engine

struct CSSRule {
    let selector: String
    let declarations: [String: String]
    let specificity: Int  // Simple specificity: ID=100, class=10, element=1
}

enum CSSEngine {

    static func parseCSS(_ css: String) -> [CSSRule] {
        let pattern = #"([^{]+)\{([^}]+)\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        var rules: [CSSRule] = []

        regex.enumerateMatches(in: css, range: NSRange(css.startIndex..., in: css)) { match, _, _ in
            guard let match = match,
                  let selRange = Range(match.range(at: 1), in: css),
                  let declRange = Range(match.range(at: 2), in: css) else { return }

            let selector = css[selRange].trimmingCharacters(in: .whitespacesAndNewlines)
            let declString = css[declRange]
            let specificity = calculateSpecificity(selector)

            var declarations: [String: String] = [:]
            declString.split(separator: ";").forEach {
                let parts = $0.split(separator: ":")
                if parts.count == 2 {
                    let key = String(parts[0]).trimmingCharacters(in: .whitespaces).lowercased()
                    declarations[key] = String(parts[1]).trimmingCharacters(in: .whitespaces)
                }
            }

            rules.append(CSSRule(selector: selector, declarations: declarations, specificity: specificity))
        }

        // Sort by specificity (lower first, so later rules override earlier ones with same specificity)
        return rules.sorted { $0.specificity < $1.specificity }
    }

    private static func calculateSpecificity(_ selector: String) -> Int {
        var score = 0
        let trimmed = selector.trimmingCharacters(in: .whitespaces)
        
        // Count ID selectors (#)
        score += trimmed.filter { $0 == "#" }.count * 100
        
        // Count class selectors (.)
        score += trimmed.filter { $0 == "." }.count * 10
        
        // Count element selectors
        let elementPattern = #"[a-zA-Z][a-zA-Z0-9]*"#
        if let regex = try? NSRegularExpression(pattern: elementPattern) {
            score += regex.numberOfMatches(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed))
        }
        
        return score
    }

    static func computeStyle(
        for node: DOMNode,
        rules: [CSSRule]
    ) -> [String: String] {

        var style: [String: String] = [:]
        let (_, attributes) = extractTagAndAttributes(from: node)
        _ = (attributes["class"] ?? "").split(separator: " ").map(String.init)

        // Apply matching CSS rules
        for rule in rules {
            if selectorMatches(rule.selector, node: node) {
                for (k, v) in rule.declarations {
                    style[k] = v
                }
            }
        }

        // Inline styles override everything
        if let inline = attributes["style"] {
            inline.split(separator: ";").forEach {
                let parts = $0.split(separator: ":")
                if parts.count == 2 {
                    style[String(parts[0]).trimmingCharacters(in: .whitespaces)] =
                        String(parts[1]).trimmingCharacters(in: .whitespaces)
                }
            }
        }

        // Legacy HTML attributes support
        if let bgcolor = attributes["bgcolor"], style["background-color"] == nil {
            style["background-color"] = bgcolor
        }
        if let width = attributes["width"], style["width"] == nil {
            style["width"] = width
        }
        if let height = attributes["height"], style["height"] == nil {
            style["height"] = height
        }

        return style
    }

    private static func extractTagAndAttributes(from node: DOMNode) -> (tag: String, attributes: [String: String]) {
        switch node.type {
        case .element(let tag, let attributes):
            return (tag.lowercased(), attributes)
        case .text:
            return ("", [:])
        }
    }

    private static func selectorMatches(_ selector: String, node: DOMNode) -> Bool {
        let selectors = selector.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return selectors.contains { selectorChainMatches($0, node: node) }
    }

    private static func selectorChainMatches(_ selector: String, node: DOMNode) -> Bool {
        let parts = selector.split(separator: " ").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !parts.isEmpty else { return false }

        var currentNode: DOMNode? = node
        for part in parts.reversed() {
            guard let match = findMatchingAncestor(for: part, startingAt: currentNode) else {
                return false
            }
            currentNode = match.parent
        }
        return true
    }

    private static func findMatchingAncestor(for selectorPart: String, startingAt node: DOMNode?) -> DOMNode? {
        var current = node
        while let candidate = current {
            if simpleSelectorMatches(selectorPart, node: candidate) {
                return candidate
            }
            current = candidate.parent
        }
        return nil
    }

    private static func simpleSelectorMatches(_ selector: String, node: DOMNode) -> Bool {
        let cleanSelector = selector.split(separator: ":").map(String.init).first?.trimmingCharacters(in: .whitespaces) ?? selector
        if cleanSelector == "*" { return true }

        let (tagName, id, classes) = parseSelectorPart(cleanSelector)
        let (nodeTag, attributes) = extractTagAndAttributes(from: node)

        if let tagName = tagName, tagName.lowercased() != nodeTag.lowercased() { return false }
        if let id = id, id.lowercased() != attributes["id"]?.lowercased() { return false }

        let nodeClasses = (attributes["class"] ?? "").split(separator: " ").map { $0.lowercased() }
        for className in classes where !nodeClasses.contains(className.lowercased()) {
            return false
        }

        return true
    }

    private static func parseSelectorPart(_ selector: String) -> (tag: String?, id: String?, classes: [String]) {
        var tagName: String?
        var id: String?
        var classes: [String] = []
        var buffer = ""
        var mode: Character? = nil

        func flushBuffer() {
            guard !buffer.isEmpty else { return }
            if mode == "#" {
                id = buffer
            } else if mode == "." {
                classes.append(buffer)
            } else if tagName == nil {
                tagName = buffer
            }
            buffer = ""
        }

        for char in selector {
            if char == "." || char == "#" {
                flushBuffer()
                mode = char
            } else {
                buffer.append(char)
            }
        }
        flushBuffer()

        return (tag: tagName, id: id, classes: classes)
    }
}

// MARK: - HTML Parser (builds DOM tree)

enum SimpleHTMLParser {

    static func parse(_ html: String, baseURL: URL? = nil) -> ParsedHTML {
        var title = ""

        // Extract title
        if let range = html.range(of: #"<title[^>]*>([^<]+)</title>"#, options: .regularExpression) {
            let match = String(html[range])
            if let inner = match.range(of: ">"), let end = match.range(of: "</") {
                title = decodeEntities(String(match[inner.upperBound..<end.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        // Extract body content between <body> and </body>, or fall back to <html>
        var body = html
        if let regex = try? NSRegularExpression(pattern: #"<body\b[^>]*>([\s\S]*?)</body>"#, options: .caseInsensitive),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           let bodyRange = Range(match.range(at: 1), in: html) {
            body = String(html[bodyRange])
        } else if let regex = try? NSRegularExpression(pattern: #"<html\b[^>]*>([\s\S]*?)</html>"#, options: .caseInsensitive),
                  let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                  let bodyRange = Range(match.range(at: 1), in: html) {
            body = String(html[bodyRange])
        }

        // Remove script/style/noscript blocks before parsing body content
        body = body.replacingOccurrences(of: #"<script\b[^>]*>[\s\S]*?</script>"#, with: "", options: .regularExpression)
        body = body.replacingOccurrences(of: #"<style\b[^>]*>[\s\S]*?</style>"#, with: "", options: .regularExpression)
        body = body.replacingOccurrences(of: #"<noscript\b[^>]*>[\s\S]*?</noscript>"#, with: "", options: .regularExpression)

        // Extract <style> blocks for CSS parsing from the full document
        var collectedCSS = ""
        let stylePattern = #"<style[^>]*>([\s\S]*?)</style>"#
        if let regex = try? NSRegularExpression(pattern: stylePattern, options: .caseInsensitive) {
            let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
            for match in matches {
                if let range = Range(match.range(at: 1), in: html) {
                    collectedCSS += html[range] + "\n"
                }
            }
        }

        // Extract external stylesheet links from the full document
        var externalStyleURLs: [URL] = []
        let linkPattern = #"<link[^>]*rel\s*=\s*['\"]?stylesheet['\"]?[^>]*>"#
        if let regex = try? NSRegularExpression(pattern: linkPattern, options: .caseInsensitive) {
            let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
            for match in matches {
                if let range = Range(match.range, in: html) {
                    let tag = String(html[range])
                    let attrs = parseTagAttrs(tag)
                    if let href = attrs["href"] {
                        if let base = baseURL, let url = URL(string: href, relativeTo: base)?.absoluteURL {
                            externalStyleURLs.append(url)
                        } else if let url = URL(string: href) {
                            externalStyleURLs.append(url)
                        }
                    }
                }
            }
        }

        let cssRules = CSSEngine.parseCSS(collectedCSS)

        // Remove script and style
        body = body.replacingOccurrences(of: #"<script[^>]*>[\s\S]*?</script>"#, with: "", options: .regularExpression)
        body = body.replacingOccurrences(of: #"<style[^>]*>[\s\S]*?</style>"#, with: "", options: .regularExpression)

        // Build DOM tree
        let domRoot = parseFragment(body, baseURL: baseURL)

        return ParsedHTML(
            title: title.isEmpty ? "Untitled" : title,
            domRoot: domRoot,
            cssRules: cssRules,
            externalStyleURLs: externalStyleURLs
        )
    }

    private static func parseFragment(_ html: String, baseURL: URL?) -> DOMNode? {
        let root = DOMNode(type: .element(tag: "body", attributes: [:]))
        var remaining = html
        var iterations = 0
        var nodeCount = 0
        let maxIterations = 25_000  // Increased for complex pages
        let maxNodes = 20_000  // Higher limit for modern devices

        while !remaining.isEmpty && iterations < maxIterations && nodeCount < maxNodes {
            iterations += 1

            guard let tagStart = remaining.range(of: "<") else {
                // Text node remainder
                let text = decodeEntities(stripTags(remaining)).trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    let textNode = DOMNode(type: .text(text))
                    root.appendChild(textNode)
                    nodeCount += 1
                }
                remaining = ""
                break
            }

            // Text before tag
            let textBefore = String(remaining[..<tagStart.lowerBound])
            let trimmedText = decodeEntities(stripTags(textBefore)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedText.isEmpty {
                let textNode = DOMNode(type: .text(trimmedText))
                root.appendChild(textNode)
                nodeCount += 1
            }

            // Find tag end
            guard let tagEnd = remaining.range(of: ">", range: tagStart.upperBound..<remaining.endIndex) else {
                remaining = ""
                break
            }

            let fullTag = String(remaining[tagStart.lowerBound..<tagEnd.upperBound])
            let tagName = parseTagName(fullTag).lowercased()
            let attrs = parseTagAttrs(fullTag)
            let afterTag = String(remaining[tagEnd.upperBound...])

            if isVoidElement(tagName) {
                // Void element: create node and append
                if nodeCount < maxNodes {
                    let node = DOMNode(type: .element(tag: tagName, attributes: attrs))
                    root.appendChild(node)
                    nodeCount += 1
                }
                remaining = afterTag
                continue
            }

            guard let closeInfo = extractUntilClosing(afterTag, tagName) else {
                // No closing tag found, treat as text
                remaining = afterTag
                continue
            }

            let innerHTML = closeInfo.found
            let remainingAfter = closeInfo.remaining

            if nodeCount >= maxNodes {
                // Stop parsing if we hit node limit
                remaining = ""
                break
            }

            if isRawTextElement(tagName) {
                // Drop raw text containers entirely; their content is not rendered.
                remaining = remainingAfter
                continue
            }

            let node = DOMNode(type: .element(tag: tagName, attributes: attrs))
            nodeCount += 1

            if !innerHTML.isEmpty {
                if tagName == "a" {
                    // For <a>, parse inner text as text node (no children)
                    let innerText = decodeEntities(stripTags(innerHTML)).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !innerText.isEmpty {
                        let textNode = DOMNode(type: .text(innerText))
                        node.appendChild(textNode)
                        nodeCount += 1
                    }
                } else if tagName == "ul" || tagName == "ol" {
                    // Parse <li> children
                    nodeCount = parseListItems(innerHTML, parentNode: node, currentCount: nodeCount, limit: maxNodes)
                } else {
                    // Recursively parse children
                    if let childFragment = parseFragment(innerHTML, baseURL: nil) {
                        for child in childFragment.children {
                            if nodeCount < maxNodes {
                                node.appendChild(child)
                                nodeCount += 1
                            }
                        }
                    }
                }
            }

            root.appendChild(node)
            remaining = remainingAfter
        }

        return root
    }

    private static func isVoidElement(_ tag: String) -> Bool {
        let voidTags: Set<String> = ["img", "br", "hr", "input", "meta", "link", "source", "area", "base", "col", "embed", "param", "track", "wbr", "!doctype"]
        return voidTags.contains(tag.lowercased())
    }

    private static func isRawTextElement(_ tag: String) -> Bool {
        let rawTextTags: Set<String> = ["script", "style", "noscript"]
        return rawTextTags.contains(tag)
    }

    private static func parseListItems(_ html: String, parentNode: DOMNode, currentCount: Int, limit: Int) -> Int {
        var rest = html
        var count = currentCount
        var iterations = 0
        
        while iterations < 500 && count < limit, let liStart = rest.range(of: "<li", options: .caseInsensitive) {
            iterations += 1
            guard let tagEnd = rest.range(of: ">", range: liStart.upperBound..<rest.endIndex) else { break }
            let contentAfter = String(rest[tagEnd.upperBound...])
            guard let inner = extractUntilClosing(contentAfter, "li") else { break }
            let liNode = DOMNode(type: .element(tag: "li", attributes: [:]))
            let text = decodeEntities(stripTags(inner.found)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                let textNode = DOMNode(type: .text(text))
                liNode.appendChild(textNode)
                count += 1
            }
            parentNode.appendChild(liNode)
            count += 1
            rest = inner.remaining
        }
        return count
    }

    private static func parseTagName(_ tag: String) -> String {
        let trimmed = tag.dropFirst().dropLast()
        if let space = trimmed.firstIndex(of: " ") {
            return String(trimmed[..<space]).trimmingCharacters(in: .whitespaces)
        }
        return String(trimmed)
    }

    private static func parseTagAttrs(_ tag: String) -> [String: String] {
        var result: [String: String] = [:]
        let pattern = #"(\w+[-\w]*)\s*=\s*(?:\"([^\"]*)\"|'([^']*)'|([^>\s]+))"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return result }
        let ns = tag as NSString
        regex.enumerateMatches(in: tag, range: NSRange(location: 0, length: ns.length)) { match, _, _ in
            guard let m = match, m.numberOfRanges >= 5,
                  let kRange = Range(m.range(at: 1), in: tag) else { return }
            let key = String(tag[kRange]).lowercased()
            let value: String?
            if let quotedValue = Range(m.range(at: 2), in: tag) {
                value = String(tag[quotedValue])
            } else if let singleQuoted = Range(m.range(at: 3), in: tag) {
                value = String(tag[singleQuoted])
            } else if let unquoted = Range(m.range(at: 4), in: tag) {
                value = String(tag[unquoted])
            } else {
                value = nil
            }
            if let value = value {
                result[key] = value
            }
        }
        return result
    }

    private static func extractUntilClosing(_ html: String, _ tagName: String) -> (found: String, remaining: String)? {
        let closeTag = "</\(tagName)>"
        guard let closeRange = html.range(of: closeTag, options: .caseInsensitive) else {
            return nil
        }

        let found = String(html[..<closeRange.lowerBound])
        let remaining = String(html[closeRange.upperBound...])
        return (found, remaining)
    }

    private static func stripTags(_ html: String) -> String {
        let noScripts = html.replacingOccurrences(of: #"<script[^>]*>[\s\S]*?</script>"#, with: " ", options: .regularExpression)
        let noStyles = noScripts.replacingOccurrences(of: #"<style[^>]*>[\s\S]*?</style>"#, with: " ", options: .regularExpression)
        return noStyles.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private static func decodeEntities(_ s: String) -> String {
        var result = s
        let entities: [(String, String)] = [
            ("&nbsp;", " "), ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&apos;", "'"), ("&#39;", "'"), ("&#x27;", "'"),
            ("&mdash;", "—"), ("&ndash;", "–"), ("&hellip;", "…"), ("&copy;", "©"),
            ("&reg;", "®"), ("&trade;", "™"), ("&bull;", "•"), ("&middot;", "·")
        ]
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        result = replaceNumericEntities(result, pattern: "&#(\\d+);", radix: 10)
        result = replaceNumericEntities(result, pattern: "&#x([0-9a-fA-F]+);", radix: 16)
        return result
    }
}

private func replaceNumericEntities(_ s: String, pattern: String, radix: Int) -> String {
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return s }
    var result = s
    let matches = regex.matches(in: s, range: NSRange(s.startIndex..., in: s))
    for m in matches.reversed() {
        guard m.numberOfRanges > 1,
              let numRange = Range(m.range(at: 1), in: s),
              let code = radix == 10 ? Int(s[numRange]) : Int(s[numRange], radix: radix),
              let scalar = Unicode.Scalar(code),
              let matchRange = Range(m.range, in: result) else { continue }
        result.replaceSubrange(matchRange, with: String(Character(scalar)))
    }
    return result
}

// MARK: - SwiftUI Rendering

struct CustomEngineView: View {
    let store: CustomEngineStore
    let baseURL: URL?
    let onPageLoad: () -> Void
    var accent: Color = Color(red: 0.38, green: 0.42, blue: 0.93)

    private let readWidth: CGFloat = 680
    private let baseFontSize: CGFloat = 16
    private let lineSpacing: CGFloat = 1.4

    private func applyBoxModel<V: View>(_ view: V, style: [String: String]) -> some View {
        var result = AnyView(view)

        if let padding = style["padding"],
           let value = Double(padding.replacingOccurrences(of: "px", with: "")) {
            result = AnyView(result.padding(value))
        }

        if let margin = style["margin"],
           let value = Double(margin.replacingOccurrences(of: "px", with: "")) {
            result = AnyView(result.padding(.vertical, value))
        }

        return result
    }

    var body: some View {
        Group {
            if store.isLoading {
                loadingView
            } else if let error = store.errorMessage {
                errorView(error)
            } else if let content = store.parsedContent, let root = content.domRoot {
                ScrollView {
                    domNodeView(root, cssRules: content.cssRules)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 24)
                        .frame(maxWidth: .infinity)
                }
                .onAppear { onPageLoad() }
            } else {
                Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func domNodeView(_ node: DOMNode, cssRules: [CSSRule]) -> AnyView {
        switch node.type {
        case .text(let text):
            return AnyView(
                Text(text)
                    .font(.system(size: baseFontSize))
                    .lineSpacing(baseFontSize * (lineSpacing - 1))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: readWidth, alignment: .leading)
            )

        case .element(let tag, let attributes):
            let style = CSSEngine.computeStyle(for: node, rules: cssRules)

            switch tag {
            case "h1", "h2", "h3", "h4", "h5", "h6":
                let level = Int(tag.dropFirst()) ?? 1
                return AnyView(
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(node.children.enumerated()), id: \.offset) { _, child in
                            domNodeView(child, cssRules: cssRules)
                        }
                    }
                    .font(.system(size: baseFontSize + CGFloat(24 - level * 2), weight: .semibold))
                    .lineSpacing(lineSpacing * 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                    .applyStyle(style)
                )

            case "p", "div":
                return AnyView(
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(node.children.enumerated()), id: \.offset) { _, child in
                            domNodeView(child, cssRules: cssRules)
                        }
                    }
                    .frame(maxWidth: readWidth, alignment: .leading)
                    .font(.system(size: baseFontSize))
                    .lineSpacing(baseFontSize * (lineSpacing - 1))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 6)
                    .applyStyle(style)
                )

            case "a":
                let href = attributes["href"] ?? "#"
                return AnyView(
                    Button {
                        resolveAndLoad(href)
                    } label: {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(node.children.enumerated()), id: \.offset) { _, child in
                                domNodeView(child, cssRules: cssRules)
                            }
                        }
                        .foregroundStyle(accent)
                        .underline()
                        .font(.system(size: baseFontSize))
                    }
                    .buttonStyle(.plain)
                )

            case "ul", "ol":
                return AnyView(
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(node.children) { child in
                            domNodeView(child, cssRules: cssRules)
                        }
                    }
                    .frame(maxWidth: readWidth, alignment: .leading)
                    .padding(.vertical, 4)
                )

            case "li":
                return AnyView(
                    HStack(alignment: .top, spacing: 10) {
                        Text("•")
                            .foregroundStyle(accent)
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(node.children) { child in
                                domNodeView(child, cssRules: cssRules)
                            }
                        }
                    }
                    .frame(maxWidth: readWidth, alignment: .leading)
                    .padding(.vertical, 2)
                )
            
            case "blockquote":
                return AnyView(
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(node.children) { child in
                            domNodeView(child, cssRules: cssRules)
                        }
                    }
                    .padding(.leading, 12)
                    .borderLeading(width: 4, color: accent)
                    .frame(maxWidth: readWidth, alignment: .leading)
                    .padding(.vertical, 8)
                    .foregroundStyle(.secondary)
                )
            
            case "code":
                return AnyView(
                    Text(node.children.compactMap { child -> String? in
                        if case .text(let text) = child.type { return text } else { return nil }
                    }.joined(separator: " "))
                    .font(.system(.caption, design: .monospaced))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                )
            
            case "pre":
                let codeText = node.children.compactMap { child -> String? in
                    if case .text(let text) = child.type { return text } else { return nil }
                }.joined(separator: "\n")
                
                return AnyView(
                    Text(codeText)
                        .font(.system(.caption, design: .monospaced))
                        .padding(12)
                        .frame(maxWidth: readWidth, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 8)
                )
            
            case "strong", "b":
                return AnyView(
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(node.children) { child in
                            domNodeView(child, cssRules: cssRules)
                        }
                    }
                    .font(.system(size: baseFontSize, weight: .semibold))
                    .frame(maxWidth: readWidth, alignment: .leading)
                )
            
            case "em", "i":
                return AnyView(
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(node.children) { child in
                            domNodeView(child, cssRules: cssRules)
                        }
                    }
                    .italic()
                    .font(.system(size: baseFontSize))
                    .frame(maxWidth: readWidth, alignment: .leading)
                )
            
            case "hr":
                return AnyView(
                    Divider()
                        .frame(maxWidth: readWidth)
                        .padding(.vertical, 12)
                )
            
            case "span":
                return AnyView(
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(node.children) { child in
                            domNodeView(child, cssRules: cssRules)
                        }
                    }
                    .frame(maxWidth: readWidth, alignment: .leading)
                    .applyStyle(style)
                )
            
            case "table":
                return AnyView(
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(node.children) { child in
                            domNodeView(child, cssRules: cssRules)
                        }
                    }
                    .frame(maxWidth: readWidth, alignment: .leading)
                    .padding(.vertical, 8)
                )
            
            case "thead", "tbody", "tfoot":
                return AnyView(
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(node.children) { child in
                            domNodeView(child, cssRules: cssRules)
                        }
                    }
                )
            
            case "tr":
                return AnyView(
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(node.children) { child in
                            domNodeView(child, cssRules: cssRules)
                        }
                    }
                    .frame(maxWidth: readWidth, alignment: .leading)
                    .border(Color.gray.opacity(0.2), width: 1)
                    .padding(.vertical, 4)
                )
            
            case "td", "th":
                return AnyView(
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(node.children) { child in
                            domNodeView(child, cssRules: cssRules)
                        }
                    }
                    .font(.system(size: baseFontSize * 0.9))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .border(Color.gray.opacity(0.15), width: 1)
                )
            
            case "form":
                return AnyView(
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(node.children) { child in
                            domNodeView(child, cssRules: cssRules)
                        }
                    }
                    .frame(maxWidth: readWidth, alignment: .leading)
                    .padding(.vertical, 8)
                )
            
            case "input":
                _ = attributes["type"] ?? "text"
                let placeholder = attributes["placeholder"] ?? attributes["name"] ?? "Input"
                return AnyView(
                    TextField(placeholder, text: .constant(""))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: readWidth, minHeight: 32)
                        .padding(.vertical, 4)
                )
            
            case "textarea":
                _ = attributes["placeholder"] ?? "Text area"
                return AnyView(
                    TextEditor(text: .constant(""))
                        .frame(maxWidth: readWidth, minHeight: 80)
                        .border(Color.gray.opacity(0.3), width: 1)
                        .padding(.vertical, 4)
                )
            
            case "button", "submit":
                let label = node.children.compactMap { child -> String? in
                    if case .text(let text) = child.type { return text } else { return nil }
                }.joined(separator: " ")
                
                return AnyView(
                    Button(label.isEmpty ? "Button" : label) { }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: readWidth, alignment: .leading)
                        .padding(.vertical, 4)
                )
            
            case "label":
                return AnyView(
                    HStack(alignment: .top, spacing: 8) {
                        ForEach(node.children) { child in
                            domNodeView(child, cssRules: cssRules)
                        }
                    }
                    .font(.system(size: baseFontSize * 0.95))
                    .frame(maxWidth: readWidth, alignment: .leading)
                    .padding(.vertical, 2)
                )
            
            case "header", "footer", "nav", "section", "article", "aside", "main":
                return AnyView(
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(node.children) { child in
                            domNodeView(child, cssRules: cssRules)
                        }
                    }
                    .frame(maxWidth: readWidth, alignment: .leading)
                    .padding(.vertical, 4)
                )

            case "img":
                if let src = attributes["src"] {
                    return AnyView(
                        imageView(src: src, alt: attributes["alt"] ?? "", style: style, attributes: attributes)
                            .frame(maxWidth: readWidth)
                            .padding(.vertical, 8)
                    )
                } else {
                    return AnyView(EmptyView())
                }

            case "br":
                return AnyView(Spacer().frame(height: 8))

            default:
                return AnyView(
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(node.children) { child in
                            domNodeView(child, cssRules: cssRules)
                        }
                    }
                    .frame(maxWidth: readWidth, alignment: .leading)
                    .padding(.vertical, 2)
                    .applyStyle(style)
                )
            }
        }
    }

    @ViewBuilder
    private func imageView(src: String, alt: String, style: [String: String], attributes: [String: String]) -> some View {
        let dimensions = resolveImageDimensions(style: style, attributes: attributes)
        if let url = resolvedImageURL(src) {
            VStack(alignment: .leading, spacing: 6) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        let baseImage = image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                        if let width = dimensions.width, let height = dimensions.height {
                            baseImage
                                .frame(width: width, height: height)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else if let width = dimensions.width {
                            baseImage
                                .frame(width: width)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else if let height = dimensions.height {
                            baseImage
                                .frame(height: height)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            baseImage
                                .frame(maxWidth: readWidth)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    case .failure:
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: readWidth, minHeight: 120)
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: readWidth, minHeight: 120)
                    @unknown default:
                        EmptyView()
                    }
                }
                if !alt.isEmpty {
                    Text(alt)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
        } else {
            EmptyView()
        }
    }

    private func resolveImageDimensions(style: [String: String], attributes: [String: String]) -> (width: CGFloat?, height: CGFloat?) {
        func parseLength(_ raw: String) -> (value: CGFloat, isPercentage: Bool)? {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if trimmed.hasSuffix("%"), let percent = Double(trimmed.dropLast()) {
                return (CGFloat(percent / 100.0), true)
            }
            let cleaned = trimmed.replacingOccurrences(of: "px", with: "")
            if let number = Double(cleaned) {
                return (CGFloat(number), false)
            }
            return nil
        }

        func dimension(from rawValue: String?) -> CGFloat? {
            guard let rawValue = rawValue, let parsed = parseLength(rawValue) else { return nil }
            if parsed.isPercentage {
                return min(readWidth, readWidth * parsed.value)
            }
            return min(readWidth, parsed.value)
        }

        let widthValue = style["width"] ?? attributes["width"]
        let heightValue = style["height"] ?? attributes["height"]

        return (width: dimension(from: widthValue), height: dimension(from: heightValue))
    }

    private func resolveAndLoad(_ href: String) {
        guard let base = baseURL else { return }
        if let url = resolveURL(href, base: base) {
            store.load(url)
        }
    }

    private func resolvedImageURL(_ src: String) -> URL? {
        guard let base = baseURL else { return URL(string: src) }
        return resolveURL(src, base: base)
    }

    private func resolveURL(_ href: String, base: URL) -> URL? {
        let trimmed = href.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed, relativeTo: base)?.absoluteURL
    }
    
    private func extractAllText(_ node: DOMNode) -> String {
        switch node.type {
        case .text(let text):
            return text
        case .element:
            return node.children.map { extractAllText($0) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }
    }
}

private func parseCSSColor(_ value: String, fallback: Color = .primary) -> Color {
    switch value.lowercased() {
    case "red": return .red
    case "blue": return .blue
    case "green": return .green
    case "black": return .black
    case "gray": return .gray
    case "white": return .white
    default: return fallback
    }
}

extension View {
    func applyBoxModel(_ style: [String: String]) -> some View {
        var result = AnyView(self)

        if let padding = style["padding"],
           let value = Double(padding.replacingOccurrences(of: "px", with: "")) {
            result = AnyView(result.padding(value))
        }

        if let margin = style["margin"],
           let value = Double(margin.replacingOccurrences(of: "px", with: "")) {
            result = AnyView(result.padding(.vertical, value))
        }

        return result
    }

    func applyStyle(_ style: [String: String]) -> some View {
        var result = AnyView(self)

        if let colorValue = style["color"] {
            result = AnyView(result.foregroundColor(parseCSSColor(colorValue)))
        }

        if let bgValue = style["background-color"] {
            result = AnyView(result.background(parseCSSColor(bgValue)))
        }

        if let padding = style["padding"],
           let value = Double(padding.replacingOccurrences(of: "px", with: "")) {
            result = AnyView(result.padding(value))
        }

        if let margin = style["margin"],
           let value = Double(margin.replacingOccurrences(of: "px", with: "")) {
            result = AnyView(result.padding(.vertical, value))
        }

        return result
    }
    
    func borderLeading(width: CGFloat, color: Color) -> some View {
        self.overlay(
            Rectangle()
                .fill(color)
                .frame(width: width),
            alignment: .leading
        )
    }
}

// MARK: - Accessibility Helpers for SwiftUI Views

extension View {
    /// Apply an accessibility label, falling back to provided fallback if label is nil or empty
    func htmlAccessibilityLabel(_ label: String?, fallback: String? = nil) -> some View {
        let accessible = (label?.isEmpty == false) ? label : fallback
        return Group {
            if let accessible = accessible {
                self.accessibilityLabel(Text(accessible))
            } else {
                self
            }
        }
    }
    /// Mark as accessibility element with optional children behavior
    func htmlAccessibilityElement(children: AccessibilityChildBehavior = .combine) -> some View {
        self.accessibilityElement(children: children)
    }
    /// Mark for accessibility heading (for <h1>..<h6> tags)
    func htmlAccessibilityHeading(level: AccessibilityHeadingLevel = .h1) -> some View {
        self.accessibilityHeading(level)
    }
    /// Apply accessibility value (e.g., for form fields)
    func htmlAccessibilityValue(_ value: String?) -> some View {
        Group {
            if let value = value {
                self.accessibilityValue(Text(value))
            } else {
                self
            }
        }
    }
    /// Apply accessibility hint
    func htmlAccessibilityHint(_ hint: String?) -> some View {
        Group {
            if let hint = hint {
                self.accessibilityHint(Text(hint))
            } else {
                self
            }
        }
    }
}

// MARK: - Tab Integration

struct CustomEngineTabView: View {
    let tab: BrowserTab
    var accent: Color = Color(red: 0.38, green: 0.42, blue: 0.93)
    let onTabUpdate: (UUID, (inout BrowserTab) -> Void) -> Void
    var onPageLoad: () -> Void

    var body: some View {
        CustomEngineView(
            store: tab.customEngineStore,
            baseURL: tab.customEngineStore.currentURL ?? tab.urlToLoad,
            onPageLoad: onPageLoad,
            accent: accent
        )
        .onAppear {
            if let url = tab.urlToLoad, (url.scheme == "http" || url.scheme == "https"),
               tab.customEngineStore.currentURL != url {
                tab.customEngineStore.load(url)
            }
            syncStoreToTab()
        }
        .onChange(of: tab.customEngineStore.canGoBack) { _, _ in syncStoreToTab() }
        .onChange(of: tab.customEngineStore.canGoForward) { _, _ in syncStoreToTab() }
        .onChange(of: tab.customEngineStore.isLoading) { _, _ in syncStoreToTab() }
        .onChange(of: tab.customEngineStore.currentURL) { _, _ in syncStoreToTab() }
        .onChange(of: tab.customEngineStore.pageTitle) { _, _ in syncStoreToTab() }
    }

    private func syncStoreToTab() {
        onTabUpdate(tab.id) {
            $0.canGoBack = tab.customEngineStore.canGoBack
            $0.canGoForward = tab.customEngineStore.canGoForward
            $0.isLoading = tab.customEngineStore.isLoading
            $0.currentURL = tab.customEngineStore.currentURL
            $0.addressText = tab.customEngineStore.currentURL?.absoluteString ?? $0.addressText
            $0.title = tab.customEngineStore.pageTitle
        }
    }
}

