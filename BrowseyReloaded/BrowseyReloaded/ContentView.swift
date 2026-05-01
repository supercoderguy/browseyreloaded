//
//  ContentView.swift
//  BrowseyReloaded
//
//  Created by Jacob Ferrari on 8/2/2026.
//

import SwiftUI
import AppKit
internal import WebKit

// MARK: - Browsey Design System (fallback when no settings in scope)
private enum BrowseyDesign {
    static let defaultAccent = Color(red: 0.38, green: 0.42, blue: 0.93)
    static let surfaceDark = Color(red: 0.12, green: 0.12, blue: 0.14)
    static let surfaceDarkElevated = Color(red: 0.16, green: 0.16, blue: 0.18)
    static let surfaceLight = Color(red: 0.96, green: 0.96, blue: 0.98)
    static let surfaceLightElevated = Color(red: 0.92, green: 0.92, blue: 0.95)
}

struct BrowserTab: Identifiable {
    let id: UUID
    var title: String
    var addressText: String
    var urlToLoad: URL?
    var currentURL: URL?
    var canGoBack: Bool
    var canGoForward: Bool
    var isLoading: Bool
    var webViewStore: WebViewStore
    var customEngineStore: CustomEngineStore

    init(id: UUID = UUID(), title: String = "New Tab", initialURL: URL? = URL(string: "https://www.apple.com")) {
        self.id = id
        self.title = title
        self.addressText = initialURL?.absoluteString ?? "about:blank"
        self.urlToLoad = initialURL
        self.currentURL = initialURL
        self.canGoBack = false
        self.canGoForward = false
        self.isLoading = false
        self.webViewStore = WebViewStore()
        self.customEngineStore = CustomEngineStore()
    }

    func engineStore(for engine: WebEngineType) -> WebEngineStore {
        switch engine {
        case .webKit: return webViewStore
        case .custom: return customEngineStore
        }
    }

    /// True when the tab is showing the new-tab/homepage screen.
    var isNewTab: Bool {
        currentURL?.absoluteString == "about:blank" || urlToLoad?.absoluteString == "about:blank"
    }
}

struct ContentView: View {
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var settings = BrowserSettings.shared
    @State private var tabs: [BrowserTab] = [BrowserTab(initialURL: BrowserSettings.shared.launchURL() ?? URL(string: "about:blank")!)]
    @State private var selectedTabId: UUID?
    @FocusState private var isAddressBarFocused: Bool
    @State private var bookmarkStore = BookmarkStore()
    @State private var sidebarVisibility: NavigationSplitViewVisibility = .detailOnly
    @State private var showGroqSheet = false
    @State private var showSettingsSheet = false
    @State private var showDownloadsSheet = false
    @State private var groqChatViewModel = GroqChatViewModel()

    private var colorScheme: ColorScheme {
        switch settings.colorSchemeOverride {
        case .auto: return systemColorScheme
        case .light: return .light
        case .dark: return .dark
        }
    }
    private var surface: Color {
        if settings.useCustomChromeColors, let c = settings.customSurfaceColor { return c }
        return colorScheme == .dark ? BrowseyDesign.surfaceDark : BrowseyDesign.surfaceLight
    }
    private var surfaceElevated: Color {
        if settings.useCustomChromeColors, let c = settings.customSurfaceElevatedColor { return c }
        return colorScheme == .dark ? BrowseyDesign.surfaceDarkElevated : BrowseyDesign.surfaceLightElevated
    }
    private var tabBarColor: Color {
        if settings.useCustomChromeColors, let c = settings.customTabBarColor { return c }
        return Color(nsColor: .windowBackgroundColor)
    }
    private var toolbarColor: Color {
        if settings.useCustomChromeColors, let c = settings.customToolbarColor { return c }
        return Color(nsColor: .windowBackgroundColor)
    }
    private var addressBarColor: Color {
        if settings.useCustomChromeColors, let c = settings.customAddressBarColor { return c }
        return Color(nsColor: .controlBackgroundColor)
    }
    private var accent: Color { settings.accentColor }

    private var selectedTab: BrowserTab? {
        tabs.first { $0.id == selectedTabId } ?? tabs.first
    }

    private var tabBarHeightValue: CGFloat {
        switch settings.tabBarHeight {
        case .compact: return 44
        case .regular: return 54
        case .large: return 64
        }
    }

    var body: some View {
        splitView
            .preferredColorScheme(settings.colorSchemeOverride == .auto ? nil : (settings.colorSchemeOverride == .dark ? .dark : .light))
        .onAppear {
                if selectedTabId == nil, let first = tabs.first {
                    selectedTabId = first.id
                }
                sidebarVisibility = settings.sidebarOpenByDefault ? .doubleColumn : .detailOnly
            }
        .onChange(of: settings.sidebarOpenByDefault) { _, open in
                sidebarVisibility = open ? .doubleColumn : .detailOnly
            }
        .onAppear { installBrowserCommands() }
        .onChange(of: tabs.count) { _, _ in installBrowserCommands() }
        .onChange(of: selectedTabId) { _, _ in installBrowserCommands() }
        .sheet(isPresented: $showSettingsSheet) {
            NavigationStack {
                SettingsView(settings: settings)
            }
        }
    }

    @ViewBuilder
    private var groqSidebarIfNeeded: some View {
        if showGroqSheet {
            GroqChatView(accent: accent, viewModel: groqChatViewModel, onClose: { showGroqSheet = false })
                .transition(.move(edge: .trailing))
        }
    }

    private var splitView: some View {
        Group {
            if settings.sidebarOnRight {
                NavigationSplitView(columnVisibility: $sidebarVisibility) {
                    browserDetailContent
                } detail: {
                    BookmarksSidebar(
                        bookmarkStore: bookmarkStore,
                        sidebarColor: settings.useCustomChromeColors ? settings.customSidebarColor : nil,
                        chromeFont: settings.chromeFont(size: 13),
                        onSelect: { url in
                            if let tabId = selectedTabId {
                                loadURLDirectly(for: tabId, url: url)
                            }
                            sidebarVisibility = .detailOnly
                        },
                        onDelete: { bookmarkStore.remove($0) },
                        onToggleSidebar: {
                            sidebarVisibility = sidebarVisibility == .detailOnly ? .doubleColumn : .detailOnly
                        }
                    )
                }
            } else {
                NavigationSplitView(columnVisibility: $sidebarVisibility) {
                    BookmarksSidebar(
                        bookmarkStore: bookmarkStore,
                        sidebarColor: settings.useCustomChromeColors ? settings.customSidebarColor : nil,
                        chromeFont: settings.chromeFont(size: 13),
                        onSelect: { url in
                            if let tabId = selectedTabId {
                                loadURLDirectly(for: tabId, url: url)
                            }
                            sidebarVisibility = .detailOnly
                        },
                        onDelete: { bookmarkStore.remove($0) },
                        onToggleSidebar: {
                            sidebarVisibility = sidebarVisibility == .detailOnly ? .doubleColumn : .detailOnly
                        }
                    )
                } detail: {
                    browserDetailContent
                }
            }
        }
    }

    private let verticalTabBarWidth: CGFloat = 220

    @ViewBuilder
    private var tabBarView: some View {
        let itemContent = Group {
            ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                TabBarItem(
                    tab: tab,
                    isSelected: tab.id == selectedTabId,
                    accent: accent,
                    showCloseButton: settings.showTabCloseButton,
                    chromeFont: settings.chromeFont(size: 13),
                    onSelect: { selectedTabId = tab.id },
                    onClose: { closeTab(at: index) }
                )
            }
            Button(action: addTab) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(accent)
            }
            .buttonStyle(.plain)
        }

        if settings.tabBarOrientation == .vertical {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 6) {
                    itemContent
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 12)
            }
            .frame(width: verticalTabBarWidth)
            .background(tabBarColor)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    itemContent
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
            .frame(height: tabBarHeightValue)
            .background(tabBarColor)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var floatingTabBarPadding: CGFloat { 12 }

    private var tabBarFloatAlignment: Alignment {
        switch settings.tabBarOrientation {
        case .horizontal: return settings.tabBarPosition == .bottom ? .bottom : .top
        case .vertical: return settings.tabBarPosition == .trailing ? .trailing : .leading
        }
    }

    @ViewBuilder
    private var browserDetailContent: some View {
        HStack(spacing: 0) {
            browserDetailInner
            groqSidebarIfNeeded
                .animation(.spring(response: 0.3, dampingFraction: 0.85), value: showGroqSheet)
        }
    }

    @ViewBuilder
    private var browserDetailInner: some View {
        let tabBar = tabBarView
        let content = ZStack {
                ForEach(tabs) { tab in
                    TabWebView(
                        tab: tab,
                        accent: accent,
                        searchEngineTemplate: settings.searchEngineTemplate,
                        webEngine: settings.webEngine,
                        onTabUpdate: updateTab,
                        onPageLoad: { isAddressBarFocused = false },
                        onSettingsRequested: { showSettingsSheet = true },
                        quickLinks: settings.quickLinks
                    )
                    .opacity(tab.id == selectedTabId ? 1 : 0)
                    .allowsHitTesting(tab.id == selectedTabId)
                    .zIndex(tab.id == selectedTabId ? 1 : 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        Group {
            if !settings.showTabBar {
                content
            } else if settings.tabBarFloats {
                ZStack(alignment: tabBarFloatAlignment) {
                    content
                    tabBar
                        .padding(floatingTabBarPadding)
                        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
                        .zIndex(10)
                }
            } else if settings.tabBarOrientation == .horizontal {
                VStack(spacing: 0) {
                    if settings.tabBarPosition == .top { tabBar }
                    content
                    if settings.tabBarPosition == .bottom { tabBar }
                }
            } else {
                let onLeading = settings.tabBarPosition == .leading || settings.tabBarPosition == .top
                let onTrailing = settings.tabBarPosition == .trailing || settings.tabBarPosition == .bottom
                HStack(spacing: 0) {
                    if onLeading { tabBar }
                    content
                    if onTrailing { tabBar }
                }
            }
        }
        .background(surface)
        .navigationTitle("")
        .toolbar {
            if let tab = selectedTab, !tab.isNewTab {
                if settings.showNavButtons {
                ToolbarItem(placement: .navigation) {
                    HStack(spacing: 4) {
                        NavButton(icon: "arrow.backward", action: { tab.engineStore(for: settings.webEngine).goBack() }, disabled: !tab.canGoBack, accent: accent)
                        NavButton(icon: "arrow.forward", action: { tab.engineStore(for: settings.webEngine).goForward() }, disabled: !tab.canGoForward, accent: accent)
                        NavButton(icon: tab.isLoading ? "stop.fill" : "arrow.clockwise", action: { tab.engineStore(for: settings.webEngine).reload() }, accent: accent)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(surfaceElevated.opacity(0.8))
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1)
                }
                }

                ToolbarItem(placement: .principal) {
                    HStack(spacing: 12) {
                        Image(systemName: "link")
                            .foregroundStyle(accent)
                            .font(settings.chromeFont(size: 13).weight(.medium))
                        TextField(settings.addressBarPlaceholder, text: addressTextBinding())
                            .textFieldStyle(.plain)
                            .font(settings.chromeFont(size: 13))
                            .focused($isAddressBarFocused)
                            .onSubmit {
                                guard isAddressBarFocused else { return }
                                loadURL(for: tab.id)
                            }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .frame(minWidth: 280, maxWidth: 520)
                    .background(
                        Capsule(style: .continuous)
                            .fill(addressBarColor.opacity(0.9))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                    )
                }

                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 10) {
                        if settings.showBookmarkStar {
                        BookmarkStarButton(
                            currentURL: tab.currentURL,
                            currentTitle: tab.title,
                            bookmarkStore: bookmarkStore,
                            accent: accent
                        )
                        }

                        if settings.showGroqButton {
                        Button(action: { showGroqSheet = true }) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                        .help("Open Groq")
                        }

                        Button(action: { showSettingsSheet = true }) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                        .help("Settings")

                        if settings.showGoButton {
                        Button(action: { loadURL(for: tab.id) }) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.glassProminent)
                        .tint(accent)
                        }
                        Button(action: { showDownloadsSheet = true }) {
                            Image(systemName: "tray.and.arrow.down")
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .sheet(isPresented: $showDownloadsSheet) {
            DownloadsView()
        }
        .onChange(of: showGroqSheet) { _, visible in
            if visible { extractPageContent() }
        }
    }

    /// Extracts visible text from the current tab's WKWebView via JavaScript.
    private func extractPageContent() {
        guard let webView = selectedTab?.webViewStore.webView else { return }
        groqChatViewModel.isLoadingPageContent = true
        groqChatViewModel.pageURL = selectedTab?.currentURL?.absoluteString
        let js = """
        (function() {
            var walker = document.createTreeWalker(
                document.body,
                NodeFilter.SHOW_TEXT,
                { acceptNode: function(node) {
                    var p = node.parentElement;
                    if (!p) return NodeFilter.FILTER_REJECT;
                    var tag = p.tagName.toLowerCase();
                    if (tag === 'script' || tag === 'style' || tag === 'noscript') return NodeFilter.FILTER_REJECT;
                    var style = window.getComputedStyle(p);
                    if (style.display === 'none' || style.visibility === 'hidden') return NodeFilter.FILTER_REJECT;
                    return NodeFilter.FILTER_ACCEPT;
                }}
            );
            var texts = [];
            while (walker.nextNode()) {
                var t = walker.currentNode.textContent.trim();
                if (t.length > 0) texts.push(t);
            }
            return texts.join(' ');
        })()
        """
        webView.evaluateJavaScript(js) { result, _ in
            DispatchQueue.main.async {
                self.groqChatViewModel.pageContent = result as? String
                self.groqChatViewModel.isLoadingPageContent = false
            }
        }
    }

    private func addressTextBinding() -> Binding<String> {
        Binding(
            get: { selectedTab?.addressText ?? "" },
            set: { newValue in
                if let index = tabs.firstIndex(where: { $0.id == selectedTabId }) {
                    tabs[index].addressText = newValue
                }
            }
        )
    }

    private func updateTab(_ id: UUID, _ transform: (inout BrowserTab) -> Void) {
        if let index = tabs.firstIndex(where: { $0.id == id }) {
            transform(&tabs[index])
        }
    }

    private func addTab() {
        let newTab = BrowserTab(initialURL: settings.newTabURL() ?? URL(string: "about:blank"))
        tabs.append(newTab)
        selectedTabId = newTab.id
    }

    private func closeTab(at index: Int) {
        guard tabs.count > 1 else { return }
        let wasSelected = tabs[index].id == selectedTabId
        tabs.remove(at: index)
        if wasSelected {
            let newIndex = min(index, tabs.count - 1)
            selectedTabId = tabs[newIndex].id
        }
    }

    private func loadURL(for tabId: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == tabId }) else { return }
        let trimmed = tabs[index].addressText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return }

        var urlString = trimmed
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            if urlString.contains(".") && !urlString.contains(" ") {
                urlString = "https://" + urlString
            } else if let searchURL = settings.searchURL(for: trimmed) {
                loadURLDirectly(for: tabId, url: searchURL)
                return
            } else {
                urlString = "https://www.google.com/search?q=" + (trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed)
            }
        }

        if let url = URL(string: urlString) {
            loadURLDirectly(for: tabId, url: url)
        }
    }

    private func loadURLDirectly(for tabId: UUID, url: URL) {
        guard let index = tabs.firstIndex(where: { $0.id == tabId }) else { return }
        tabs[index].urlToLoad = url
        tabs[index].addressText = url.absoluteString
        tabs[index].engineStore(for: settings.webEngine).load(url)
    }

    private func installBrowserCommands() {
        let target = BrowserCommandsTarget.shared
        target.newTab = addTab
        target.closeTab = {
            guard let id = selectedTabId, let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
            closeTab(at: idx)
        }
        target.reload = { selectedTab?.engineStore(for: settings.webEngine).reload() }
        target.focusAddressBar = { isAddressBarFocused = true }
        target.goHome = {
            guard let id = selectedTabId, let url = URL(string: settings.homePageURL) else { return }
            loadURLDirectly(for: id, url: url)
        }
        target.nextTab = {
            guard let idx = tabs.firstIndex(where: { $0.id == selectedTabId }) else { return }
            let next = min(idx + 1, tabs.count - 1)
            if next != idx { selectedTabId = tabs[next].id }
        }
        target.previousTab = {
            guard let idx = tabs.firstIndex(where: { $0.id == selectedTabId }) else { return }
            let prev = max(idx - 1, 0)
            if prev != idx { selectedTabId = tabs[prev].id }
        }
    }
}

private struct BookmarkStarButton: View {
    let currentURL: URL?
    let currentTitle: String
    var bookmarkStore: BookmarkStore
    var accent: Color = BrowseyDesign.defaultAccent

    private var canBookmark: Bool {
        guard let url = currentURL else { return false }
        return url.absoluteString != "about:blank"
    }

    private var isBookmarked: Bool {
        guard let url = currentURL else { return false }
        return bookmarkStore.contains(url: url)
    }

    var body: some View {
        Button(action: {
            guard let url = currentURL else { return }
            if isBookmarked, let b = bookmarkStore.bookmark(for: url) {
                bookmarkStore.remove(b)
            } else {
                let title = currentTitle.isEmpty ? (url.host ?? url.absoluteString) : currentTitle
                bookmarkStore.add(title: title, url: url)
            }
        }) {
            Image(systemName: isBookmarked ? "star.fill" : "star")
                .font(.system(size: 12))
                .foregroundStyle(isBookmarked ? accent : .secondary)
        }
        .buttonStyle(.plain)
        .disabled(!canBookmark)
        .opacity(canBookmark ? 1 : 0.4)
        .help(isBookmarked ? "Remove bookmark" : "Add bookmark")
    }
}

private struct BookmarksSidebar: View {
    var bookmarkStore: BookmarkStore
    var sidebarColor: Color? = nil
    var chromeFont: Font = .system(size: 13)
    let onSelect: (URL) -> Void
    let onDelete: (Bookmark) -> Void
    let onToggleSidebar: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Bookmarks")
                    .font(chromeFont.weight(.semibold))
                    .font(.system(size: 18))

                Spacer()

                Button(action: onToggleSidebar) {
                    Image(systemName: "sidebar.leading")
                        .font(chromeFont.weight(.semibold))
                        .font(.system(size: 14))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Hide sidebar")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(sidebarColor ?? Color(nsColor: .windowBackgroundColor))

            List {
                Section {
                    if bookmarkStore.bookmarks.isEmpty {
                        ContentUnavailableView(
                            "No Bookmarks",
                            systemImage: "star",
                            description: Text("Click the star in the toolbar to bookmark the current page.")
                        )
                    } else {
                        ForEach(bookmarkStore.bookmarks) { bookmark in
                            Button(action: { onSelect(bookmark.url) }) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(bookmark.title)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .font(chromeFont.weight(.medium))
                                    Text(bookmark.url.absoluteString)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    onDelete(bookmark)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        }
        .frame(minWidth: 240)
    }
}

private struct NavButton: View {
    let icon: String
    let action: () -> Void
    var disabled: Bool = false
    var accent: Color = BrowseyDesign.defaultAccent

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
                .background(
                    Group {
                        if !disabled && isHovered {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(accent.opacity(0.15))
                        } else {
                            Color.clear
                        }
                    }
                )
                .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct TabBarItem: View {
    let tab: BrowserTab
    let isSelected: Bool
    var accent: Color = BrowseyDesign.defaultAccent
    var showCloseButton: BrowserSettings.ShowTabCloseButton = .always
    var chromeFont: Font = .system(size: 13)
    let onSelect: () -> Void
    let onClose: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onSelect) {
                Text(displayTitle)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .font(chromeFont.weight(isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? accent : .primary)
            }
            .buttonStyle(.plain)

            if showCloseButton == .always || (showCloseButton == .onHover && isHovered) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .onHover { isHovered = $0 }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .frame(maxWidth: 180)
        .background(
            Capsule(style: .continuous)
                .fill(.regularMaterial)
                .opacity(isSelected ? 1 : 0)
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.primary.opacity(isSelected ? 0.15 : 0), lineWidth: 1)
                )
        )
        .offset(y: isSelected ? -2 : 0)
        .animation(.easeInOut(duration: 0.25), value: isSelected)
        .zIndex(isSelected ? 1 : 0)
    }

    private var displayTitle: String {
        if !tab.title.isEmpty && tab.title != "New Tab" {
            return tab.title
        }
        if let url = tab.currentURL, url.absoluteString != "about:blank" {
            return url.host ?? url.absoluteString
        }
        return "New Tab"
    }
}

private struct HomepageView: View {
    var accent: Color = BrowseyDesign.defaultAccent
    var searchEngineTemplate: String = "https://www.google.com/search?q=%@"
    var quickLinks: [QuickLink]
    var onRequestURL: (URL) -> Void
    var onSettingsRequested: () -> Void = {}
    @State private var searchText: String = ""

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Welcome to Browsey")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: onSettingsRequested) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
            .padding(.horizontal, 40)
            .padding(.top, 40)

            HStack {
                TextField("Search or enter address", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        submitSearch()
                    }
                Button(action: submitSearch) {
                    Image(systemName: "magnifyingglass")
                        .padding(8)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
            }
            .padding(.horizontal, 40)
            .frame(maxWidth: 600)

            VStack(spacing: 12) {
                Text("Quick Links")
                    .font(.headline)
                    .padding(.top, 10)

                HStack(spacing: 20) {
                    ForEach(quickLinks) { link in
                        Button(action: {
                            if let url = link.toURL() {
                                onRequestURL(url)
                            }
                        }) {
                            Text(link.title)
                                .fontWeight(.medium)
                                .frame(minWidth: 80)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(accent.opacity(0.15))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color.clear
        )
    }

    private func submitSearch() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var urlString = trimmed
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            if urlString.contains(".") && !urlString.contains(" ") {
                urlString = "https://" + urlString
            } else {
                let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
                urlString = searchEngineTemplate.replacingOccurrences(of: "%@", with: encoded)
            }
        }
        if let url = URL(string: urlString) {
            onRequestURL(url)
        }
    }
}

struct TabWebView: View {
    let tab: BrowserTab
    var accent: Color = BrowseyDesign.defaultAccent
    var searchEngineTemplate: String = "https://www.google.com/search?q=%@"
    var webEngine: WebEngineType = .webKit
    let onTabUpdate: (UUID, (inout BrowserTab) -> Void) -> Void
    var onPageLoad: () -> Void
    var onSettingsRequested: () -> Void = {}
    var quickLinks: [QuickLink] = []

    var body: some View {
        if tab.isNewTab {
            HomepageView(accent: accent, searchEngineTemplate: searchEngineTemplate, quickLinks: quickLinks, onRequestURL: { url in
                onTabUpdate(tab.id) { t in
                    t.urlToLoad = url
                    t.addressText = url.absoluteString
                    t.currentURL = url
                }
                tab.engineStore(for: webEngine).load(url)
                onPageLoad()
            }, onSettingsRequested: onSettingsRequested)
        } else if webEngine == .custom {
            CustomEngineTabView(
                tab: tab,
                accent: accent,
                onTabUpdate: onTabUpdate,
                onPageLoad: onPageLoad
            )
        } else {
            WebView(
                initialURL: tab.urlToLoad,
                canGoBack: Binding(
                    get: { tab.canGoBack },
                    set: { newValue in onTabUpdate(tab.id) { $0.canGoBack = newValue } }
                ),
                canGoForward: Binding(
                    get: { tab.canGoForward },
                    set: { newValue in onTabUpdate(tab.id) { $0.canGoForward = newValue } }
                ),
                isLoading: Binding(
                    get: { tab.isLoading },
                    set: { newValue in onTabUpdate(tab.id) { $0.isLoading = newValue } }
                ),
                currentURL: Binding(
                    get: { tab.currentURL },
                    set: { newValue in onTabUpdate(tab.id) { $0.currentURL = newValue } }
                ),
                pageTitle: Binding(
                    get: { tab.title },
                    set: { newValue in onTabUpdate(tab.id) { $0.title = newValue } }
                ),
                webViewStore: tab.webViewStore,
                onPageLoad: onPageLoad,
                // MARK: UserAgent string
                customUserAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36 BrowseyReloaded/0.1"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: tab.currentURL) { _, newURL in
                if let url = newURL {
                    onTabUpdate(tab.id) { $0.addressText = url.absoluteString }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .frame(minWidth: 800, minHeight: 600)
}

