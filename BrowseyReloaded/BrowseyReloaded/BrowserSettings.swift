//
//  BrowserSettings.swift
//  BrowseyReloaded
//
//  Created by Jacob Ferrari on 8/2/2026.
//

import SwiftUI
import AppKit

struct QuickLink: Codable, Identifiable {
    var id: UUID
    var title: String
    var url: String

    init(id: UUID = UUID(), title: String, url: String) {
        self.id = id
        self.title = title
        self.url = url
    }

    func toURL() -> URL? {
        URL(string: url)
    }
}

/// User-customizable browser settings. Persisted to UserDefaults.
/// Uses stored properties so @Observable triggers live updates when settings change.
@Observable
final class BrowserSettings {
    static let shared = BrowserSettings()

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let accentRed = "BrowseyReloaded.Settings.AccentRed"
        static let accentGreen = "BrowseyReloaded.Settings.AccentGreen"
        static let accentBlue = "BrowseyReloaded.Settings.AccentBlue"
        static let colorSchemeOverride = "BrowseyReloaded.Settings.ColorSchemeOverride"
        static let showNavButtons = "BrowseyReloaded.Settings.ShowNavButtons"
        static let showBookmarkStar = "BrowseyReloaded.Settings.ShowBookmarkStar"
        static let showBookmarksButton = "BrowseyReloaded.Settings.ShowBookmarksButton"
        static let showGroqButton = "BrowseyReloaded.Settings.ShowGroqButton"
        static let showGoButton = "BrowseyReloaded.Settings.ShowGoButton"
        static let addressBarPlaceholder = "BrowseyReloaded.Settings.AddressBarPlaceholder"
        static let homePageURL = "BrowseyReloaded.Settings.HomePageURL"
        static let newTabPage = "BrowseyReloaded.Settings.NewTabPage"
        static let newTabCustomURL = "BrowseyReloaded.Settings.NewTabCustomURL"
        static let searchEngineTemplate = "BrowseyReloaded.Settings.SearchEngineTemplate"
        static let sidebarOpenByDefault = "BrowseyReloaded.Settings.SidebarOpenByDefault"
        static let tabBarHeight = "BrowseyReloaded.Settings.TabBarHeight"
        static let blockAds = "BrowseyReloaded.Settings.BlockAds"
        static let defaultZoom = "BrowseyReloaded.Settings.DefaultZoom"
        static let pageFontSize = "BrowseyReloaded.Settings.PageFontSize"
        static let minimumFontSize = "BrowseyReloaded.Settings.MinimumFontSize"
        static let blockPopups = "BrowseyReloaded.Settings.BlockPopups"
        static let allowAutoplay = "BrowseyReloaded.Settings.AllowAutoplay"
        static let showTabCloseButton = "BrowseyReloaded.Settings.ShowTabCloseButton"
        static let layoutDensity = "BrowseyReloaded.Settings.LayoutDensity"
        static let userAgentOverride = "BrowseyReloaded.Settings.UserAgentOverride"
        static let launchPageOption = "BrowseyReloaded.Settings.LaunchPageOption"
        static let launchCustomURL = "BrowseyReloaded.Settings.LaunchCustomURL"
        static let tabBarPosition = "BrowseyReloaded.Settings.TabBarPosition"
        static let tabBarOrientation = "BrowseyReloaded.Settings.TabBarOrientation"
        static let showTabBar = "BrowseyReloaded.Settings.ShowTabBar"
        static let tabBarFloats = "BrowseyReloaded.Settings.TabBarFloats"
        static let sidebarOnRight = "BrowseyReloaded.Settings.SidebarOnRight"
        static let chromeFontName = "BrowseyReloaded.Settings.ChromeFontName"
        static let chromeFontSize = "BrowseyReloaded.Settings.ChromeFontSize"
        static let useCustomChromeColors = "BrowseyReloaded.Settings.UseCustomChromeColors"
        static let customToolbarR = "BrowseyReloaded.Settings.CustomToolbarR"
        static let customToolbarG = "BrowseyReloaded.Settings.CustomToolbarG"
        static let customToolbarB = "BrowseyReloaded.Settings.CustomToolbarB"
        static let customTabBarR = "BrowseyReloaded.Settings.CustomTabBarR"
        static let customTabBarG = "BrowseyReloaded.Settings.CustomTabBarG"
        static let customTabBarB = "BrowseyReloaded.Settings.CustomTabBarB"
        static let customAddressBarR = "BrowseyReloaded.Settings.CustomAddressBarR"
        static let customAddressBarG = "BrowseyReloaded.Settings.CustomAddressBarG"
        static let customAddressBarB = "BrowseyReloaded.Settings.CustomAddressBarB"
        static let customSidebarR = "BrowseyReloaded.Settings.CustomSidebarR"
        static let customSidebarG = "BrowseyReloaded.Settings.CustomSidebarG"
        static let customSidebarB = "BrowseyReloaded.Settings.CustomSidebarB"
        static let customSurfaceR = "BrowseyReloaded.Settings.CustomSurfaceR"
        static let customSurfaceG = "BrowseyReloaded.Settings.CustomSurfaceG"
        static let customSurfaceB = "BrowseyReloaded.Settings.CustomSurfaceB"
        static let customSurfaceElevatedR = "BrowseyReloaded.Settings.CustomSurfaceElevatedR"
        static let customSurfaceElevatedG = "BrowseyReloaded.Settings.CustomSurfaceElevatedG"
        static let customSurfaceElevatedB = "BrowseyReloaded.Settings.CustomSurfaceElevatedB"
        static let webEngine = "BrowseyReloaded.Settings.WebEngine"
        static let quickLinks = "BrowseyReloaded.Settings.QuickLinks"
        static let javaScriptEnabled = "BrowseyReloaded.Settings.JavaScriptEnabled"
        static let javaScriptCanOpenWindows = "BrowseyReloaded.Settings.JavaScriptCanOpenWindows"
        static let plugInsEnabled = "BrowseyReloaded.Settings.PlugInsEnabled"
        static let allowsBackForwardGestures = "BrowseyReloaded.Settings.AllowsBackForwardGestures"
        static let developerExtrasEnabled = "BrowseyReloaded.Settings.DeveloperExtrasEnabled"
        static let defaultUserAgent = "BrowseyReloaded.Settings.DefaultUserAgent"
    }

    enum ColorSchemeOverride: String, CaseIterable {
        case auto = "Auto"
        case light = "Light"
        case dark = "Dark"
    }

    enum NewTabPage: String, CaseIterable {
        case blank = "Blank"
        case home = "Home"
        case custom = "Custom URL"
    }

    enum TabBarHeight: String, CaseIterable {
        case compact = "Compact"
        case regular = "Regular"
        case large = "Large"
    }

    enum ShowTabCloseButton: String, CaseIterable {
        case always = "Always"
        case onHover = "On hover"
    }

    enum LayoutDensity: String, CaseIterable {
        case compact = "Compact"
        case comfortable = "Comfortable"
        case spacious = "Spacious"
    }

    enum LaunchPageOption: String, CaseIterable {
        case sameAsNewTab = "Same as new tab"
        case blank = "Blank"
        case home = "Home"
        case custom = "Custom URL"
    }

    enum TabBarPosition: String, CaseIterable {
        case top = "Top"
        case bottom = "Bottom"
        case leading = "Left"
        case trailing = "Right"
    }

    enum TabBarOrientation: String, CaseIterable {
        case horizontal = "Horizontal"
        case vertical = "Vertical"
    }

    static let searchEnginePresets: [(id: String, name: String, template: String)] = [
        ("google", "Google", "https://www.google.com/search?q=%@"),
        ("duckduckgo", "DuckDuckGo", "https://duckduckgo.com/?q=%@"),
        ("bing", "Bing", "https://www.bing.com/search?q=%@"),
        ("yahoo", "Yahoo", "https://search.yahoo.com/search?p=%@"),
    ]

    // MARK: - Stored properties (observed by SwiftUI; synced to UserDefaults)
    private var _accentRed: Double
    private var _accentGreen: Double
    private var _accentBlue: Double
    private var _colorSchemeOverride: ColorSchemeOverride
    private var _tabBarHeight: TabBarHeight
    private var _showNavButtons: Bool
    private var _showBookmarkStar: Bool
    private var _showBookmarksButton: Bool
    private var _showGroqButton: Bool
    private var _showGoButton: Bool
    private var _addressBarPlaceholder: String
    private var _homePageURL: String
    private var _newTabPage: NewTabPage
    private var _newTabCustomURL: String
    private var _searchEngineTemplate: String
    private var _sidebarOpenByDefault: Bool
    private var _blockAds: Bool
    private var _defaultZoom: Double
    private var _pageFontSize: Int
    private var _minimumFontSize: Int
    private var _blockPopups: Bool
    private var _allowAutoplay: Bool
    private var _showTabCloseButton: ShowTabCloseButton
    private var _layoutDensity: LayoutDensity
    private var _userAgentOverride: String
    private var _launchPageOption: LaunchPageOption
    private var _launchCustomURL: String
    private var _tabBarPosition: TabBarPosition
    private var _tabBarOrientation: TabBarOrientation
    private var _showTabBar: Bool
    private var _tabBarFloats: Bool
    private var _sidebarOnRight: Bool
    private var _chromeFontName: String
    private var _chromeFontSize: Int
    private var _useCustomChromeColors: Bool
    private var _customToolbarR: Double
    private var _customToolbarG: Double
    private var _customToolbarB: Double
    private var _customTabBarR: Double
    private var _customTabBarG: Double
    private var _customTabBarB: Double
    private var _customAddressBarR: Double
    private var _customAddressBarG: Double
    private var _customAddressBarB: Double
    private var _customSidebarR: Double
    private var _customSidebarG: Double
    private var _customSidebarB: Double
    private var _customSurfaceR: Double
    private var _customSurfaceG: Double
    private var _customSurfaceB: Double
    private var _customSurfaceElevatedR: Double
    private var _customSurfaceElevatedG: Double
    private var _customSurfaceElevatedB: Double
    private var _webEngine: WebEngineType
    private var _quickLinks: [QuickLink]
    private var _javaScriptEnabled: Bool
    private var _javaScriptCanOpenWindows: Bool
    private var _plugInsEnabled: Bool
    private var _allowsBackForwardGestures: Bool
    private var _developerExtrasEnabled: Bool
    private var _defaultUserAgent: String

    // MARK: - Web Engine
    var webEngine: WebEngineType {
        get { _webEngine }
        set {
            _webEngine = newValue
            defaults.set(newValue.rawValue, forKey: Keys.webEngine)
        }
    }

    // MARK: - Appearance
    var accentColor: Color {
        get {
            Color(red: _accentRed, green: _accentGreen, blue: _accentBlue)
        }
        set {
            let (r, g, b) = newValue.components
            _accentRed = r
            _accentGreen = g
            _accentBlue = b
            defaults.set(r, forKey: Keys.accentRed)
            defaults.set(g, forKey: Keys.accentGreen)
            defaults.set(b, forKey: Keys.accentBlue)
        }
    }

    var colorSchemeOverride: ColorSchemeOverride {
        get { _colorSchemeOverride }
        set {
            _colorSchemeOverride = newValue
            defaults.set(newValue.rawValue, forKey: Keys.colorSchemeOverride)
        }
    }

    var tabBarHeight: TabBarHeight {
        get { _tabBarHeight }
        set {
            _tabBarHeight = newValue
            defaults.set(newValue.rawValue, forKey: Keys.tabBarHeight)
        }
    }

    // MARK: - Toolbar
    var showNavButtons: Bool {
        get { _showNavButtons }
        set {
            _showNavButtons = newValue
            defaults.set(newValue, forKey: Keys.showNavButtons)
        }
    }

    var showBookmarkStar: Bool {
        get { _showBookmarkStar }
        set {
            _showBookmarkStar = newValue
            defaults.set(newValue, forKey: Keys.showBookmarkStar)
        }
    }

    var showBookmarksButton: Bool {
        get { _showBookmarksButton }
        set {
            _showBookmarksButton = newValue
            defaults.set(newValue, forKey: Keys.showBookmarksButton)
        }
    }

    var showGroqButton: Bool {
        get { _showGroqButton }
        set {
            _showGroqButton = newValue
            defaults.set(newValue, forKey: Keys.showGroqButton)
        }
    }

    var showGoButton: Bool {
        get { _showGoButton }
        set {
            _showGoButton = newValue
            defaults.set(newValue, forKey: Keys.showGoButton)
        }
    }

    var addressBarPlaceholder: String {
        get { _addressBarPlaceholder }
        set {
            _addressBarPlaceholder = newValue
            defaults.set(newValue, forKey: Keys.addressBarPlaceholder)
        }
    }

    // MARK: - Start / Tabs
    var homePageURL: String {
        get { _homePageURL }
        set {
            _homePageURL = newValue
            defaults.set(newValue, forKey: Keys.homePageURL)
        }
    }

    var newTabPage: NewTabPage {
        get { _newTabPage }
        set {
            _newTabPage = newValue
            defaults.set(newValue.rawValue, forKey: Keys.newTabPage)
        }
    }

    var newTabCustomURL: String {
        get { _newTabCustomURL }
        set {
            _newTabCustomURL = newValue
            defaults.set(newValue, forKey: Keys.newTabCustomURL)
        }
    }

    var searchEngineTemplate: String {
        get { _searchEngineTemplate }
        set {
            _searchEngineTemplate = newValue
            defaults.set(newValue, forKey: Keys.searchEngineTemplate)
        }
    }

    var sidebarOpenByDefault: Bool {
        get { _sidebarOpenByDefault }
        set {
            _sidebarOpenByDefault = newValue
            defaults.set(newValue, forKey: Keys.sidebarOpenByDefault)
        }
    }

    // MARK: - Privacy / Blocking
    var blockAds: Bool {
        get { _blockAds }
        set {
            _blockAds = newValue
            defaults.set(newValue, forKey: Keys.blockAds)
            ContentBlocker.shared.compileIfNeeded(enabled: newValue)
        }
    }

    var blockPopups: Bool {
        get { _blockPopups }
        set {
            _blockPopups = newValue
            defaults.set(newValue, forKey: Keys.blockPopups)
        }
    }

    var allowAutoplay: Bool {
        get { _allowAutoplay }
        set {
            _allowAutoplay = newValue
            defaults.set(newValue, forKey: Keys.allowAutoplay)
        }
    }

    // MARK: - Page / Display
    var defaultZoom: Double {
        get { _defaultZoom }
        set {
            _defaultZoom = min(max(newValue, 0.5), 3.0)
            defaults.set(_defaultZoom, forKey: Keys.defaultZoom)
        }
    }

    var pageFontSize: Int {
        get { _pageFontSize }
        set {
            _pageFontSize = min(max(newValue, 8), 72)
            defaults.set(_pageFontSize, forKey: Keys.pageFontSize)
        }
    }

    var minimumFontSize: Int {
        get { _minimumFontSize }
        set {
            _minimumFontSize = min(max(newValue, 1), 24)
            defaults.set(_minimumFontSize, forKey: Keys.minimumFontSize)
        }
    }

    var showTabCloseButton: ShowTabCloseButton {
        get { _showTabCloseButton }
        set {
            _showTabCloseButton = newValue
            defaults.set(newValue.rawValue, forKey: Keys.showTabCloseButton)
        }
    }

    var layoutDensity: LayoutDensity {
        get { _layoutDensity }
        set {
            _layoutDensity = newValue
            defaults.set(newValue.rawValue, forKey: Keys.layoutDensity)
        }
    }

    var userAgentOverride: String {
        get { _userAgentOverride }
        set {
            _userAgentOverride = newValue
            defaults.set(newValue, forKey: Keys.userAgentOverride)
        }
    }

    // MARK: - Launch
    var launchPageOption: LaunchPageOption {
        get { _launchPageOption }
        set {
            _launchPageOption = newValue
            defaults.set(newValue.rawValue, forKey: Keys.launchPageOption)
        }
    }

    var launchCustomURL: String {
        get { _launchCustomURL }
        set {
            _launchCustomURL = newValue
            defaults.set(newValue, forKey: Keys.launchCustomURL)
        }
    }

    // MARK: - Layout / Position
    var tabBarPosition: TabBarPosition {
        get { _tabBarPosition }
        set {
            _tabBarPosition = newValue
            defaults.set(newValue.rawValue, forKey: Keys.tabBarPosition)
        }
    }

    var tabBarOrientation: TabBarOrientation {
        get { _tabBarOrientation }
        set {
            _tabBarOrientation = newValue
            defaults.set(newValue.rawValue, forKey: Keys.tabBarOrientation)
        }
    }

    var showTabBar: Bool {
        get { _showTabBar }
        set {
            _showTabBar = newValue
            defaults.set(newValue, forKey: Keys.showTabBar)
        }
    }

    var tabBarFloats: Bool {
        get { _tabBarFloats }
        set {
            _tabBarFloats = newValue
            defaults.set(newValue, forKey: Keys.tabBarFloats)
        }
    }

    var sidebarOnRight: Bool {
        get { _sidebarOnRight }
        set {
            _sidebarOnRight = newValue
            defaults.set(newValue, forKey: Keys.sidebarOnRight)
        }
    }

    // MARK: - Chrome typography
    var chromeFontName: String {
        get { _chromeFontName }
        set {
            _chromeFontName = newValue
            defaults.set(newValue, forKey: Keys.chromeFontName)
        }
    }

    var chromeFontSize: Int {
        get { _chromeFontSize }
        set {
            _chromeFontSize = min(max(newValue, 0), 24)
            defaults.set(_chromeFontSize, forKey: Keys.chromeFontSize)
        }
    }

    // MARK: - Custom chrome colors (optional overrides)
    var useCustomChromeColors: Bool {
        get { _useCustomChromeColors }
        set {
            _useCustomChromeColors = newValue
            defaults.set(newValue, forKey: Keys.useCustomChromeColors)
        }
    }

    var customToolbarColor: Color? {
        get { _customToolbarR >= 0 ? Color(red: _customToolbarR, green: _customToolbarG, blue: _customToolbarB) : nil }
        set {
            if let (r, g, b) = newValue?.components {
                _customToolbarR = r; _customToolbarG = g; _customToolbarB = b
                defaults.set(r, forKey: Keys.customToolbarR); defaults.set(g, forKey: Keys.customToolbarG); defaults.set(b, forKey: Keys.customToolbarB)
            } else {
                _customToolbarR = -1
                defaults.removeObject(forKey: Keys.customToolbarR)
                defaults.removeObject(forKey: Keys.customToolbarG)
                defaults.removeObject(forKey: Keys.customToolbarB)
            }
        }
    }

    var customTabBarColor: Color? {
        get { _customTabBarR >= 0 ? Color(red: _customTabBarR, green: _customTabBarG, blue: _customTabBarB) : nil }
        set {
            if let (r, g, b) = newValue?.components {
                _customTabBarR = r; _customTabBarG = g; _customTabBarB = b
                defaults.set(r, forKey: Keys.customTabBarR); defaults.set(g, forKey: Keys.customTabBarG); defaults.set(b, forKey: Keys.customTabBarB)
            } else {
                _customTabBarR = -1
                defaults.removeObject(forKey: Keys.customTabBarR)
                defaults.removeObject(forKey: Keys.customTabBarG)
                defaults.removeObject(forKey: Keys.customTabBarB)
            }
        }
    }

    var customAddressBarColor: Color? {
        get { _customAddressBarR >= 0 ? Color(red: _customAddressBarR, green: _customAddressBarG, blue: _customAddressBarB) : nil }
        set {
            if let (r, g, b) = newValue?.components {
                _customAddressBarR = r; _customAddressBarG = g; _customAddressBarB = b
                defaults.set(r, forKey: Keys.customAddressBarR); defaults.set(g, forKey: Keys.customAddressBarG); defaults.set(b, forKey: Keys.customAddressBarB)
            } else {
                _customAddressBarR = -1
                defaults.removeObject(forKey: Keys.customAddressBarR)
                defaults.removeObject(forKey: Keys.customAddressBarG)
                defaults.removeObject(forKey: Keys.customAddressBarB)
            }
        }
    }

    var customSidebarColor: Color? {
        get { _customSidebarR >= 0 ? Color(red: _customSidebarR, green: _customSidebarG, blue: _customSidebarB) : nil }
        set {
            if let (r, g, b) = newValue?.components {
                _customSidebarR = r; _customSidebarG = g; _customSidebarB = b
                defaults.set(r, forKey: Keys.customSidebarR); defaults.set(g, forKey: Keys.customSidebarG); defaults.set(b, forKey: Keys.customSidebarB)
            } else {
                _customSidebarR = -1
                defaults.removeObject(forKey: Keys.customSidebarR)
                defaults.removeObject(forKey: Keys.customSidebarG)
                defaults.removeObject(forKey: Keys.customSidebarB)
            }
        }
    }

    var customSurfaceColor: Color? {
        get { _customSurfaceR >= 0 ? Color(red: _customSurfaceR, green: _customSurfaceG, blue: _customSurfaceB) : nil }
        set {
            if let (r, g, b) = newValue?.components {
                _customSurfaceR = r; _customSurfaceG = g; _customSurfaceB = b
                defaults.set(r, forKey: Keys.customSurfaceR); defaults.set(g, forKey: Keys.customSurfaceG); defaults.set(b, forKey: Keys.customSurfaceB)
            } else {
                _customSurfaceR = -1
                defaults.removeObject(forKey: Keys.customSurfaceR)
                defaults.removeObject(forKey: Keys.customSurfaceG)
                defaults.removeObject(forKey: Keys.customSurfaceB)
            }
        }
    }

    var customSurfaceElevatedColor: Color? {
        get { _customSurfaceElevatedR >= 0 ? Color(red: _customSurfaceElevatedR, green: _customSurfaceElevatedG, blue: _customSurfaceElevatedB) : nil }
        set {
            if let (r, g, b) = newValue?.components {
                _customSurfaceElevatedR = r; _customSurfaceElevatedG = g; _customSurfaceElevatedB = b
                defaults.set(r, forKey: Keys.customSurfaceElevatedR); defaults.set(g, forKey: Keys.customSurfaceElevatedG); defaults.set(b, forKey: Keys.customSurfaceElevatedB)
            } else {
                _customSurfaceElevatedR = -1
                defaults.removeObject(forKey: Keys.customSurfaceElevatedR)
                defaults.removeObject(forKey: Keys.customSurfaceElevatedG)
                defaults.removeObject(forKey: Keys.customSurfaceElevatedB)
            }
        }
    }

    // MARK: - Quick Links
    var quickLinks: [QuickLink] {
        get { _quickLinks }
        set {
            _quickLinks = newValue
            if let encoded = try? JSONEncoder().encode(newValue) {
                defaults.set(encoded, forKey: Keys.quickLinks)
            }
        }
    }

    // MARK: - WebKit Preferences
    var javaScriptEnabled: Bool {
        get { _javaScriptEnabled }
        set {
            _javaScriptEnabled = newValue
            defaults.set(newValue, forKey: Keys.javaScriptEnabled)
        }
    }

    var javaScriptCanOpenWindows: Bool {
        get { _javaScriptCanOpenWindows }
        set {
            _javaScriptCanOpenWindows = newValue
            defaults.set(newValue, forKey: Keys.javaScriptCanOpenWindows)
        }
    }

    var plugInsEnabled: Bool {
        get { _plugInsEnabled }
        set {
            _plugInsEnabled = newValue
            defaults.set(newValue, forKey: Keys.plugInsEnabled)
        }
    }

    var allowsBackForwardGestures: Bool {
        get { _allowsBackForwardGestures }
        set {
            _allowsBackForwardGestures = newValue
            defaults.set(newValue, forKey: Keys.allowsBackForwardGestures)
        }
    }

    var developerExtrasEnabled: Bool {
        get { _developerExtrasEnabled }
        set {
            _developerExtrasEnabled = newValue
            defaults.set(newValue, forKey: Keys.developerExtrasEnabled)
        }
    }

    var defaultUserAgent: String {
        get { _defaultUserAgent }
        set {
            _defaultUserAgent = newValue
            defaults.set(newValue, forKey: Keys.defaultUserAgent)
        }
    }

    // MARK: - Helpers
    func newTabURL() -> URL? {
        switch newTabPage {
        case .blank: return URL(string: "about:blank")
        case .home: return URL(string: homePageURL)
        case .custom: return URL(string: newTabCustomURL)
        }
    }

    /// URL to open in the first tab when the app launches.
    func launchURL() -> URL? {
        switch launchPageOption {
        case .sameAsNewTab: return newTabURL()
        case .blank: return URL(string: "about:blank")
        case .home: return URL(string: homePageURL)
        case .custom: return URL(string: launchCustomURL)
        }
    }

    /// Font for chrome (tabs, toolbar, sidebar). Size 0 = use default (13).
    func chromeFont(size: CGFloat = 13) -> Font {
        let fontSize = CGFloat(chromeFontSize > 0 ? chromeFontSize : 13)
        if chromeFontName.isEmpty {
            return .system(size: fontSize)
        }
        return .custom(chromeFontName, size: fontSize)
    }

    func searchURL(for query: String) -> URL? {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = searchEngineTemplate.replacingOccurrences(of: "%@", with: encoded)
        return URL(string: urlString)
    }

    init() {
        let d = UserDefaults.standard
        func validDouble(_ key: String, fallback: Double) -> Double {
            let v = d.double(forKey: key)
            return (v > 0 && v <= 1) ? v : fallback
        }
        _accentRed = validDouble(Keys.accentRed, fallback: 0.38)
        _accentGreen = validDouble(Keys.accentGreen, fallback: 0.42)
        _accentBlue = validDouble(Keys.accentBlue, fallback: 0.93)
        _colorSchemeOverride = ColorSchemeOverride(rawValue: d.string(forKey: Keys.colorSchemeOverride) ?? "Auto") ?? .auto
        _tabBarHeight = TabBarHeight(rawValue: d.string(forKey: Keys.tabBarHeight) ?? "Regular") ?? .regular
        _showNavButtons = d.object(forKey: Keys.showNavButtons) as? Bool ?? true
        _showBookmarkStar = d.object(forKey: Keys.showBookmarkStar) as? Bool ?? true
        _showBookmarksButton = d.object(forKey: Keys.showBookmarksButton) as? Bool ?? true
        _showGroqButton = d.object(forKey: Keys.showGroqButton) as? Bool ?? true
        _showGoButton = d.object(forKey: Keys.showGoButton) as? Bool ?? true
        _addressBarPlaceholder = d.string(forKey: Keys.addressBarPlaceholder) ?? "Search or enter address"
        _homePageURL = d.string(forKey: Keys.homePageURL) ?? "https://www.google.com"
        _newTabPage = NewTabPage(rawValue: d.string(forKey: Keys.newTabPage) ?? "Blank") ?? .blank
        _newTabCustomURL = d.string(forKey: Keys.newTabCustomURL) ?? "https://www.google.com"
        _searchEngineTemplate = d.string(forKey: Keys.searchEngineTemplate) ?? BrowserSettings.searchEnginePresets[0].template
        _sidebarOpenByDefault = d.object(forKey: Keys.sidebarOpenByDefault) as? Bool ?? false
        _blockAds = d.object(forKey: Keys.blockAds) as? Bool ?? true
        let defaultZoomRaw = d.object(forKey: Keys.defaultZoom) as? Double ?? 1.0
        _defaultZoom = (defaultZoomRaw >= 0.5 && defaultZoomRaw <= 3) ? defaultZoomRaw : 1.0
        let pageFontSizeRaw = d.object(forKey: Keys.pageFontSize) as? Int ?? 16
        _pageFontSize = (pageFontSizeRaw >= 8 && pageFontSizeRaw <= 72) ? pageFontSizeRaw : 16
        let minimumFontSizeRaw = d.object(forKey: Keys.minimumFontSize) as? Int ?? 8
        _minimumFontSize = (minimumFontSizeRaw >= 1 && minimumFontSizeRaw <= 24) ? minimumFontSizeRaw : 8
        _blockPopups = d.object(forKey: Keys.blockPopups) as? Bool ?? true
        _allowAutoplay = d.object(forKey: Keys.allowAutoplay) as? Bool ?? false
        _showTabCloseButton = ShowTabCloseButton(rawValue: d.string(forKey: Keys.showTabCloseButton) ?? "Always") ?? .always
        _layoutDensity = LayoutDensity(rawValue: d.string(forKey: Keys.layoutDensity) ?? "Comfortable") ?? .comfortable
        _userAgentOverride = d.string(forKey: Keys.userAgentOverride) ?? ""
        _launchPageOption = LaunchPageOption(rawValue: d.string(forKey: Keys.launchPageOption) ?? "Same as new tab") ?? .sameAsNewTab
        _launchCustomURL = d.string(forKey: Keys.launchCustomURL) ?? "https://www.google.com"
        _tabBarPosition = TabBarPosition(rawValue: d.string(forKey: Keys.tabBarPosition) ?? "Top") ?? .top
        _tabBarOrientation = TabBarOrientation(rawValue: d.string(forKey: Keys.tabBarOrientation) ?? "Horizontal") ?? .horizontal
        _showTabBar = d.object(forKey: Keys.showTabBar) as? Bool ?? true
        _tabBarFloats = d.object(forKey: Keys.tabBarFloats) as? Bool ?? false
        _sidebarOnRight = d.object(forKey: Keys.sidebarOnRight) as? Bool ?? false
        _chromeFontName = d.string(forKey: Keys.chromeFontName) ?? ""
        _chromeFontSize = (d.object(forKey: Keys.chromeFontSize) as? Int).map { min(max($0, 0), 24) } ?? 0
        _useCustomChromeColors = d.object(forKey: Keys.useCustomChromeColors) as? Bool ?? false
        func loadRGB(_ rKey: String, _ gKey: String, _ bKey: String) -> (Double, Double, Double) {
            guard d.object(forKey: rKey) != nil else { return (-1, -1, -1) }
            return (d.double(forKey: rKey), d.double(forKey: gKey), d.double(forKey: bKey))
        }
        let t = loadRGB(Keys.customToolbarR, Keys.customToolbarG, Keys.customToolbarB)
        _customToolbarR = t.0; _customToolbarG = t.1; _customToolbarB = t.2
        let tb = loadRGB(Keys.customTabBarR, Keys.customTabBarG, Keys.customTabBarB)
        _customTabBarR = tb.0; _customTabBarG = tb.1; _customTabBarB = tb.2
        let ab = loadRGB(Keys.customAddressBarR, Keys.customAddressBarG, Keys.customAddressBarB)
        _customAddressBarR = ab.0; _customAddressBarG = ab.1; _customAddressBarB = ab.2
        let sb = loadRGB(Keys.customSidebarR, Keys.customSidebarG, Keys.customSidebarB)
        _customSidebarR = sb.0; _customSidebarG = sb.1; _customSidebarB = sb.2
        let s = loadRGB(Keys.customSurfaceR, Keys.customSurfaceG, Keys.customSurfaceB)
        _customSurfaceR = s.0; _customSurfaceG = s.1; _customSurfaceB = s.2
        let se = loadRGB(Keys.customSurfaceElevatedR, Keys.customSurfaceElevatedG, Keys.customSurfaceElevatedB)
        _customSurfaceElevatedR = se.0; _customSurfaceElevatedG = se.1; _customSurfaceElevatedB = se.2
        _webEngine = WebEngineType(rawValue: d.string(forKey: Keys.webEngine) ?? "WebKit") ?? .webKit
        
        // Load quick links or use defaults
        if let data = d.data(forKey: Keys.quickLinks),
           let decoded = try? JSONDecoder().decode([QuickLink].self, from: data) {
            _quickLinks = decoded
        } else {
            _quickLinks = [
                QuickLink(title: "Apple", url: "https://www.apple.com"),
                QuickLink(title: "Google", url: "https://www.google.com"),
                QuickLink(title: "Wikipedia", url: "https://www.wikipedia.org")
            ]
        }
        
        // WebKit preferences
        _javaScriptEnabled = d.object(forKey: Keys.javaScriptEnabled) as? Bool ?? true
        _javaScriptCanOpenWindows = d.object(forKey: Keys.javaScriptCanOpenWindows) as? Bool ?? false
        _plugInsEnabled = d.object(forKey: Keys.plugInsEnabled) as? Bool ?? false
        _allowsBackForwardGestures = d.object(forKey: Keys.allowsBackForwardGestures) as? Bool ?? true
        _developerExtrasEnabled = d.object(forKey: Keys.developerExtrasEnabled) as? Bool ?? true
        _defaultUserAgent = d.string(forKey: Keys.defaultUserAgent) ?? "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        
        if _blockAds { ContentBlocker.shared.compileIfNeeded(enabled: true) }
    }

    // MARK: - Config File Export/Import
    struct ConfigData: Codable {
        var appearance: AppearanceConfig
        var browser: BrowserConfig
        var tabs: TabsConfig
        var webKit: WebKitConfig
        var privacy: PrivacyConfig
    }

    struct AppearanceConfig: Codable {
        var accentColor: [Double]
        var colorScheme: String
        var tabBarHeight: String
        var layoutDensity: String
        var chromeFontName: String
        var chromeFontSize: Int
        var useCustomColors: Bool
    }

    struct BrowserConfig: Codable {
        var homePageURL: String
        var newTabPage: String
        var newTabCustomURL: String
        var searchEngine: String
        var defaultZoom: Double
        var quickLinks: [QuickLinkConfig]
    }

    struct QuickLinkConfig: Codable {
        var title: String
        var url: String
    }

    struct TabsConfig: Codable {
        var tabBarOrientation: String
        var tabBarPosition: String
        var showTabBar: Bool
        var tabBarFloats: Bool
        var sidebarOnRight: Bool
    }

    struct WebKitConfig: Codable {
        var javaScriptEnabled: Bool
        var javaScriptCanOpenWindows: Bool
        var plugInsEnabled: Bool
        var allowsBackForwardGestures: Bool
        var developerExtrasEnabled: Bool
        var defaultUserAgent: String
        var userAgentOverride: String
    }

    struct PrivacyConfig: Codable {
        var blockAds: Bool
        var blockPopups: Bool
        var allowAutoplay: Bool
    }

    func exportConfig() -> ConfigData {
        ConfigData(
            appearance: AppearanceConfig(
                accentColor: [_accentRed, _accentGreen, _accentBlue],
                colorScheme: colorSchemeOverride.rawValue,
                tabBarHeight: tabBarHeight.rawValue,
                layoutDensity: layoutDensity.rawValue,
                chromeFontName: chromeFontName,
                chromeFontSize: chromeFontSize,
                useCustomColors: useCustomChromeColors
            ),
            browser: BrowserConfig(
                homePageURL: homePageURL,
                newTabPage: newTabPage.rawValue,
                newTabCustomURL: newTabCustomURL,
                searchEngine: searchEngineTemplate,
                defaultZoom: defaultZoom,
                quickLinks: quickLinks.map { QuickLinkConfig(title: $0.title, url: $0.url) }
            ),
            tabs: TabsConfig(
                tabBarOrientation: tabBarOrientation.rawValue,
                tabBarPosition: tabBarPosition.rawValue,
                showTabBar: showTabBar,
                tabBarFloats: tabBarFloats,
                sidebarOnRight: sidebarOnRight
            ),
            webKit: WebKitConfig(
                javaScriptEnabled: javaScriptEnabled,
                javaScriptCanOpenWindows: javaScriptCanOpenWindows,
                plugInsEnabled: plugInsEnabled,
                allowsBackForwardGestures: allowsBackForwardGestures,
                developerExtrasEnabled: developerExtrasEnabled,
                defaultUserAgent: defaultUserAgent,
                userAgentOverride: userAgentOverride
            ),
            privacy: PrivacyConfig(
                blockAds: blockAds,
                blockPopups: blockPopups,
                allowAutoplay: allowAutoplay
            )
        )
    }

    func importConfig(_ config: ConfigData) {
        // Appearance
        if config.appearance.accentColor.count == 3 {
            _accentRed = config.appearance.accentColor[0]
            _accentGreen = config.appearance.accentColor[1]
            _accentBlue = config.appearance.accentColor[2]
            defaults.set(_accentRed, forKey: Keys.accentRed)
            defaults.set(_accentGreen, forKey: Keys.accentGreen)
            defaults.set(_accentBlue, forKey: Keys.accentBlue)
        }
        if let scheme = ColorSchemeOverride(rawValue: config.appearance.colorScheme) {
            colorSchemeOverride = scheme
        }
        if let height = TabBarHeight(rawValue: config.appearance.tabBarHeight) {
            tabBarHeight = height
        }
        if let density = LayoutDensity(rawValue: config.appearance.layoutDensity) {
            layoutDensity = density
        }
        chromeFontName = config.appearance.chromeFontName
        chromeFontSize = config.appearance.chromeFontSize
        useCustomChromeColors = config.appearance.useCustomColors

        // Browser
        homePageURL = config.browser.homePageURL
        if let newTab = NewTabPage(rawValue: config.browser.newTabPage) {
            newTabPage = newTab
        }
        newTabCustomURL = config.browser.newTabCustomURL
        searchEngineTemplate = config.browser.searchEngine
        defaultZoom = config.browser.defaultZoom
        quickLinks = config.browser.quickLinks.map { QuickLink(title: $0.title, url: $0.url) }

        // Tabs
        if let orientation = TabBarOrientation(rawValue: config.tabs.tabBarOrientation) {
            tabBarOrientation = orientation
        }
        if let position = TabBarPosition(rawValue: config.tabs.tabBarPosition) {
            tabBarPosition = position
        }
        showTabBar = config.tabs.showTabBar
        tabBarFloats = config.tabs.tabBarFloats
        sidebarOnRight = config.tabs.sidebarOnRight

        // WebKit
        javaScriptEnabled = config.webKit.javaScriptEnabled
        javaScriptCanOpenWindows = config.webKit.javaScriptCanOpenWindows
        plugInsEnabled = config.webKit.plugInsEnabled
        allowsBackForwardGestures = config.webKit.allowsBackForwardGestures
        developerExtrasEnabled = config.webKit.developerExtrasEnabled
        defaultUserAgent = config.webKit.defaultUserAgent
        userAgentOverride = config.webKit.userAgentOverride

        // Privacy
        blockAds = config.privacy.blockAds
        blockPopups = config.privacy.blockPopups
        allowAutoplay = config.privacy.allowAutoplay
    }

    func loadConfigFile(_ url: URL) -> Bool {
        do {
            let data = try Data(contentsOf: url)
            let config = try JSONDecoder().decode(ConfigData.self, from: data)
            importConfig(config)
            return true
        } catch {
            print("Failed to load config: \(error)")
            return false
        }
    }

    func saveConfigFile(_ url: URL) -> Bool {
        do {
            let config = exportConfig()
            let data = try JSONEncoder().encode(config)
            try data.write(to: url)
            return true
        } catch {
            print("Failed to save config: \(error)")
            return false
        }
    }
}

private extension Color {
    var components: (Double, Double, Double) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        NSColor(self).usingColorSpace(.sRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
    }
}
