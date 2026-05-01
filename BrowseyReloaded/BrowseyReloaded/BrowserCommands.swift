//
//  BrowserCommands.swift
//  BrowseyReloaded
//
//  Keyboard shortcuts and menu commands. ContentView registers its
//  handlers with the shared target so commands affect the key window.
//

import SwiftUI

/// Shared target for browser menu/keyboard commands. ContentView sets these when it appears/updates.
@Observable
final class BrowserCommandsTarget {
    static let shared = BrowserCommandsTarget()

    var newTab: (() -> Void)?
    var closeTab: (() -> Void)?
    var reload: (() -> Void)?
    var focusAddressBar: (() -> Void)?
    var goHome: (() -> Void)?
    var nextTab: (() -> Void)?
    var previousTab: (() -> Void)?

    private init() {}
}
