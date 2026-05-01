//
//  ExtensionNativeMessageBridge.swift
//  BrowseyReloaded
//
//  Delivers postMessage payloads from user scripts to Swift (for debugging or future UI).
//

import Foundation

/// Payloads from `browser.runtime.sendNativeMessage(extensionId, data)` in injected scripts.
@Observable
final class ExtensionNativeMessageBridge {
    static let shared = ExtensionNativeMessageBridge()

    struct Message: Identifiable {
        let id = UUID()
        let extensionId: String
        let payload: Any?
        let receivedAt = Date()
    }

    /// Most recent message (append-only for observation).
    private(set) var messages: [Message] = []

    private let limit = 200

    private init() {}

    func append(extensionId: String, payload: Any?) {
        let m = Message(extensionId: extensionId, payload: payload)
        messages.append(m)
        if messages.count > limit {
            messages.removeFirst(messages.count - limit)
        }
    }
}
