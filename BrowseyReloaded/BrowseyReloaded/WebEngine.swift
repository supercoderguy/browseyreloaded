//
//  WebEngine.swift
//  BrowseyReloaded
//
//  Protocol and types for pluggable web engines.
//

import SwiftUI

/// Which rendering engine to use for web content.
enum WebEngineType: String, CaseIterable {
    case webKit = "WebKit"
    case custom = "Browsey Engine"
}

/// Store interface for engine navigation. Both WebKit and custom engines use a store
/// that the toolbar can call for load, back, forward, reload.
protocol WebEngineStore: AnyObject {
    func load(_ url: URL)
    func goBack()
    func goForward()
    func reload()
}
