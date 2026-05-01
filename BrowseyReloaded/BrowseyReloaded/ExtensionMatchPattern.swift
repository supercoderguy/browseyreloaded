//
//  ExtensionMatchPattern.swift
//  BrowseyReloaded
//
//  Chrome-style match patterns (subset) for user scripts / “extensions”.
//

import Foundation

enum ExtensionMatchPattern {
    /// Returns true when `url` matches the Chrome-style `pattern` (e.g. `https://*/*`, `*://*.example.com/*`).
    static func urlMatchesPattern(_ url: URL, pattern raw: String) -> Bool {
        let pattern = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if pattern.isEmpty { return true }
        guard let parsed = parse(pattern) else { return false }

        let scheme = url.scheme?.lowercased() ?? ""
        if parsed.scheme != "*" && scheme != parsed.scheme.lowercased() { return false }

        let host = url.host.map { $0.lowercased() } ?? ""
        if !hostMatches(hostname: host, pattern: parsed.host) { return false }

        let pathForMatch = url.path + (url.query.map { "?" + $0 } ?? "")
        return pathMatches(urlPath: pathForMatch, patternPath: parsed.path)
    }

    /// Empty `matchPatterns` means “all URLs” (`*://*/*`). Excludes win if any pattern matches.
    static func shouldRunScript(url: URL, matchPatterns: [String], excludePatterns: [String]) -> Bool {
        let matches = matchPatterns.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let effectiveMatches = matches.isEmpty ? ["*://*/*"] : matches
        let matched = effectiveMatches.contains { urlMatchesPattern(url, pattern: $0) }
        if !matched { return false }
        let excludes = excludePatterns.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return !excludes.contains { urlMatchesPattern(url, pattern: $0) }
    }

    private struct Parsed {
        let scheme: String
        let host: String
        let path: String
    }

    private static func parse(_ pattern: String) -> Parsed? {
        guard let colonIdx = pattern.firstIndex(of: ":"),
              pattern.distance(from: colonIdx, to: pattern.endIndex) >= 3,
              pattern[pattern.index(after: colonIdx)...].hasPrefix("//") else { return nil }
        let scheme = String(pattern[..<colonIdx])
        let afterScheme = pattern.index(colonIdx, offsetBy: 3)
        let rest = String(pattern[afterScheme...])
        guard let slashIdx = rest.firstIndex(of: "/") else {
            return Parsed(scheme: scheme, host: rest, path: "/*")
        }
        let host = String(rest[..<slashIdx])
        var path = String(rest[slashIdx...])
        if path.isEmpty { path = "/" }
        return Parsed(scheme: scheme, host: host, path: path)
    }

    private static func hostMatches(hostname: String, pattern: String) -> Bool {
        if pattern == "*" { return true }
        if pattern.hasPrefix("*.") {
            let suffix = String(pattern.dropFirst(2))
            return hostname == suffix || hostname.hasSuffix("." + suffix)
        }
        return hostname == pattern
    }

    /// Path segment of a match pattern: `*` → any substring (Chrome-style).
    private static func pathMatches(urlPath: String, patternPath: String) -> Bool {
        if patternPath == "/*" { return true }
        var escaped = ""
        for ch in patternPath {
            switch ch {
            case "*": escaped += ".*"
            case "\\", ".", "+", "?", "^", "$", "(", ")", "[", "]", "{", "}", "|":
                escaped += "\\" + String(ch)
            default: escaped.append(ch)
            }
        }
        guard let re = try? NSRegularExpression(pattern: "^\(escaped)$", options: []) else { return false }
        let range = NSRange(location: 0, length: (urlPath as NSString).length)
        return re.firstMatch(in: urlPath, options: [], range: range) != nil
    }
}
