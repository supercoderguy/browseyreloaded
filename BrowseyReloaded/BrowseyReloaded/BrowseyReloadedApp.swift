//
//  BrowseyReloadedApp.swift
//  BrowseyReloaded
//
//  Created by Jacob Ferrari on 8/2/2026.
//

import SwiftUI

@main
struct BrowseyReloadedApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Tab") {
                    BrowserCommandsTarget.shared.newTab?()
                }
                .keyboardShortcut("t", modifiers: .command)
                Button("Close Tab") {
                    BrowserCommandsTarget.shared.closeTab?()
                }
                .keyboardShortcut("w", modifiers: .command)
            }
            CommandMenu("Navigate") {
                Button("Reload Page") {
                    BrowserCommandsTarget.shared.reload?()
                }
                .keyboardShortcut("r", modifiers: .command)
                Button("Focus Address Bar") {
                    BrowserCommandsTarget.shared.focusAddressBar?()
                }
                .keyboardShortcut("l", modifiers: .command)
                Button("Go Home") {
                    BrowserCommandsTarget.shared.goHome?()
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])
                Divider()
                Button("Next Tab") {
                    BrowserCommandsTarget.shared.nextTab?()
                }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .control])
                Button("Previous Tab") {
                    BrowserCommandsTarget.shared.previousTab?()
                }
                .keyboardShortcut(.leftArrow, modifiers: [.command, .control])
            }
            CommandGroup(replacing: .appInfo) {
                Button("About Browsey") {
                    showAboutWindow()
                }
            }
            CommandGroup(replacing: .help) {
                Button("Browsey Help") {
                    openHelp()
                }
                .keyboardShortcut("?", modifiers: .command)
            }
        }
    }
}

private func showAboutWindow() {
    let alert = NSAlert()
    alert.messageText = "About Browsey"
    alert.informativeText = """
    Browsey Reloaded v0.1 (Open Beta)
    
    A modern web browser for macOS with advanced features including:
    • Tabbed browsing with customizable UI
    • Built-in bookmark management
    • AI-powered chat integration (Groq)
    • Custom web engine support
    • Content blocking and user scripts
    • Extension support
    
    Copyright (C) 2026 Linux User Lucario

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
    """
    alert.icon = NSImage(named: "AppIcon") ?? NSImage(named: NSImage.applicationIconName)
    alert.addButton(withTitle: "OK")
    alert.runModal()
}

private func openHelp() {
    if let url = URL(string: "https://github.com/supercoderguy/BrowseyReloaded") {
        NSWorkspace.shared.open(url)
    }
}

