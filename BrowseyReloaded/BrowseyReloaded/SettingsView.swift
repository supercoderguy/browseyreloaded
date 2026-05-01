//
//  SettingsView.swift
//  BrowseyReloaded
//
//  Created by Jacob Ferrari on 8/2/2026.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var settings: BrowserSettings

    var body: some View {
        Form {
            appearanceSection
            launchSection
            toolbarSection
            tabsAndStartSection
            quickLinksSection
            searchSection
            layoutSection
            typographySection
            customColorsSection
            privacySection
            pageSection
            webKitSection
            advancedSection
            configSection
            extensionsSection
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .frame(minWidth: 440, minHeight: 420)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Text("Browsey Reloaded v0.1 (Open Beta)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.vertical, 8)
            .background(.regularMaterial)
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            ColorPicker("Accent color", selection: Binding(
                get: { settings.accentColor },
                set: { settings.accentColor = $0 }
            ))
            Picker("Color scheme", selection: $settings.colorSchemeOverride) {
                ForEach(BrowserSettings.ColorSchemeOverride.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            Picker("Tab bar size", selection: $settings.tabBarHeight) {
                ForEach(BrowserSettings.TabBarHeight.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            Picker("Layout density", selection: $settings.layoutDensity) {
                ForEach(BrowserSettings.LayoutDensity.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
        }
    }

    private var launchSection: some View {
        Section("On launch") {
            Text("The first tab when you open Browsey uses the page below.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("Open", selection: $settings.launchPageOption) {
                ForEach(BrowserSettings.LaunchPageOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            if settings.launchPageOption == .custom {
                TextField("Custom launch URL", text: $settings.launchCustomURL)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var toolbarSection: some View {
        Section("Toolbar") {
            TextField("Address bar placeholder", text: Binding(
                get: { settings.addressBarPlaceholder },
                set: { settings.addressBarPlaceholder = $0 }
            ))
            Toggle("Back / Forward / Reload", isOn: $settings.showNavButtons)
            Toggle("Bookmark star", isOn: $settings.showBookmarkStar)
            Toggle("Bookmarks sidebar button", isOn: $settings.showBookmarksButton)
            Toggle("Groq AI button", isOn: $settings.showGroqButton)
            Toggle("Go button", isOn: $settings.showGoButton)
        }
    }

    private var tabsAndStartSection: some View {
        Section("Tabs & start") {
            TextField("Home page URL", text: $settings.homePageURL)
                .textFieldStyle(.roundedBorder)
            Picker("New tab opens", selection: $settings.newTabPage) {
                ForEach(BrowserSettings.NewTabPage.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            if settings.newTabPage == .custom {
                TextField("Custom new tab URL", text: $settings.newTabCustomURL)
                    .textFieldStyle(.roundedBorder)
            }
            Toggle("Show bookmarks sidebar by default", isOn: $settings.sidebarOpenByDefault)
            Picker("Tab close button", selection: $settings.showTabCloseButton) {
                ForEach(BrowserSettings.ShowTabCloseButton.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
        }
    }

    private var layoutSection: some View {
        Section("Layout & position") {
            Picker("Tab bar orientation", selection: $settings.tabBarOrientation) {
                ForEach(BrowserSettings.TabBarOrientation.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            Picker("Tab bar position", selection: $settings.tabBarPosition) {
                Group {
                    if settings.tabBarOrientation == .horizontal {
                        Text("Top").tag(BrowserSettings.TabBarPosition.top)
                        Text("Bottom").tag(BrowserSettings.TabBarPosition.bottom)
                    } else {
                        Text("Left").tag(BrowserSettings.TabBarPosition.leading)
                        Text("Right").tag(BrowserSettings.TabBarPosition.trailing)
                    }
                }
            }
            Toggle("Show tab bar", isOn: $settings.showTabBar)
            Toggle("Floating tab bar", isOn: $settings.tabBarFloats)
                .disabled(!settings.showTabBar)
            Toggle("Sidebar on right", isOn: $settings.sidebarOnRight)
        }
    }

    private var typographySection: some View {
        Section("Chrome typography") {
            TextField("Font name (blank = system)", text: $settings.chromeFontName)
                .textFieldStyle(.roundedBorder)
            Stepper("Font size: \(settings.chromeFontSize == 0 ? "Default" : "\(settings.chromeFontSize) pt")", value: $settings.chromeFontSize, in: 0...24)
        }
    }

    private var customColorsSection: some View {
        Section("Custom chrome colors") {
            Toggle("Use custom colors", isOn: $settings.useCustomChromeColors)
            if settings.useCustomChromeColors {
                ColorPicker("Toolbar", selection: Binding(
                    get: { settings.customToolbarColor ?? Color(nsColor: .windowBackgroundColor) },
                    set: { settings.customToolbarColor = $0 }
                ))
                ColorPicker("Tab bar", selection: Binding(
                    get: { settings.customTabBarColor ?? Color(nsColor: .windowBackgroundColor) },
                    set: { settings.customTabBarColor = $0 }
                ))
                ColorPicker("Address bar", selection: Binding(
                    get: { settings.customAddressBarColor ?? Color(nsColor: .controlBackgroundColor) },
                    set: { settings.customAddressBarColor = $0 }
                ))
                ColorPicker("Sidebar", selection: Binding(
                    get: { settings.customSidebarColor ?? Color(nsColor: .windowBackgroundColor) },
                    set: { settings.customSidebarColor = $0 }
                ))
                ColorPicker("Content background", selection: Binding(
                    get: { settings.customSurfaceColor ?? Color(white: 0.96) },
                    set: { settings.customSurfaceColor = $0 }
                ))
                ColorPicker("Elevated surfaces", selection: Binding(
                    get: { settings.customSurfaceElevatedColor ?? Color(white: 0.92) },
                    set: { settings.customSurfaceElevatedColor = $0 }
                ))
            }
        }
    }

    private var quickLinksSection: some View {
        Section("New Tab Quick Links") {
            List {
                ForEach($settings.quickLinks) { $link in
                    HStack(spacing: 12) {
                        TextField("Title", text: $link.title)
                            .textFieldStyle(.roundedBorder)
                        TextField("URL", text: $link.url)
                            .textFieldStyle(.roundedBorder)
                        Button(action: {
                            settings.quickLinks.removeAll { $0.id == link.id }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.inset)
            .frame(minHeight: 100, maxHeight: 300)

            Button(action: {
                settings.quickLinks.append(QuickLink(title: "New Link", url: "https://example.com"))
            }) {
                Label("Add Quick Link", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.bordered)
        }
    }

    private var searchSection: some View {
        Section("Search") {
            Picker("Search engine", selection: Binding(
                get: {
                    BrowserSettings.searchEnginePresets.first(where: { $0.template == settings.searchEngineTemplate })?.id
                        ?? "google"
                },
                set: { id in
                    if let preset = BrowserSettings.searchEnginePresets.first(where: { $0.id == id }) {
                        settings.searchEngineTemplate = preset.template
                    }
                }
            )) {
                ForEach(BrowserSettings.searchEnginePresets, id: \.id) { preset in
                    Text(preset.name).tag(preset.id)
                }
            }
        }
    }

    private var privacySection: some View {
        Section("Privacy & blocking") {
            Toggle("Block ads (built-in list)", isOn: $settings.blockAds)
            Toggle("Block pop-ups", isOn: $settings.blockPopups)
            Toggle("Allow autoplay", isOn: $settings.allowAutoplay)
        }
    }

    private var pageSection: some View {
        Section("Page display") {
            HStack {
                Text("Default zoom")
                Slider(value: $settings.defaultZoom, in: 0.5...2.0, step: 0.1)
                Text("\(Int(settings.defaultZoom * 100))%")
                    .frame(width: 36, alignment: .trailing)
            }
            Stepper("Default font size: \(settings.pageFontSize) pt", value: $settings.pageFontSize, in: 8...72)
            Stepper("Minimum font size: \(settings.minimumFontSize) pt", value: $settings.minimumFontSize, in: 1...24)
        }
    }

    private var webKitSection: some View {
        Section("WebKit Preferences") {
            Toggle("JavaScript enabled", isOn: $settings.javaScriptEnabled)
            Toggle("JavaScript can open windows", isOn: $settings.javaScriptCanOpenWindows)
            Toggle("Plug-ins enabled", isOn: $settings.plugInsEnabled)
            Toggle("Allow back/forward gestures", isOn: $settings.allowsBackForwardGestures)
            Toggle("Developer extras enabled", isOn: $settings.developerExtrasEnabled)
            TextField("Default User-Agent", text: $settings.defaultUserAgent)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
        }
    }

    private var configSection: some View {
        Section("Configuration") {
            HStack(spacing: 12) {
                Button(action: exportConfig) {
                    Label("Export Settings", systemImage: "arrow.down.doc")
                }
                .buttonStyle(.bordered)
                
                Button(action: importConfig) {
                    Label("Import Settings", systemImage: "arrow.up.doc")
                }
                .buttonStyle(.bordered)
            }
            
            Text("Export and import browser settings to/from a JSON config file.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func exportConfig() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "browsey-config.json"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            _ = BrowserSettings.shared.saveConfigFile(url)
        }
    }

    private func importConfig() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowsMultipleSelection = false
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            _ = BrowserSettings.shared.loadConfigFile(url)
        }
    }

    private var advancedSection: some View {
        Section("Advanced") {
            Picker("Web engine", selection: $settings.webEngine) {
                ForEach(WebEngineType.allCases, id: \.self) { engine in
                    Text(engine.rawValue).tag(engine)
                }
            }
            if settings.webEngine == .custom {
                Text("Browsey Engine is a minimal renderer for simple pages. No JavaScript, limited layout. Use WebKit for full compatibility.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            TextField("User-Agent override (blank = default)", text: $settings.userAgentOverride)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var extensionsSection: some View {
        Section("Extensions") {
            Text("Scripts support URL match patterns (Chrome-style), optional CSS, isolated or page JS world, and browser.runtime.sendNativeMessage for Swift.")
                .font(.caption)
                .foregroundStyle(.secondary)
            ExtensionsScriptList()
            PackagedExtensionsList()
        }
    }
}

// MARK: - User scripts list for Settings
private struct ExtensionsScriptList: View {
    @State private var scriptStore = UserScriptStore.shared
    @State private var showEditor = false
    @State private var editingScript: UserScript?

    var body: some View {
        List {
            ForEach(scriptStore.scripts) { script in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(script.name)
                            .font(.system(size: 13, weight: .medium))
                        Text(scriptSubtitle(script))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { script.isEnabled },
                        set: { newValue in
                            var s = script
                            s.isEnabled = newValue
                            scriptStore.update(s)
                        }
                    ))
                    .labelsHidden()
                    Button("Edit") {
                        editingScript = script
                        showEditor = true
                    }
                    .buttonStyle(.borderless)
                    Button("Delete", role: .destructive) {
                        scriptStore.remove(script)
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.inset)
        .frame(minHeight: 120, maxHeight: 220)
        HStack(spacing: 12) {
            Button("Add script") {
                let newId = UUID()
                editingScript = UserScript(
                    id: newId,
                    name: "New script",
                    script: "// Your JavaScript here\n// browser.runtime.sendNativeMessage(\"\(newId.uuidString)\", { ping: true });",
                    matchPatterns: ["*://*/*"]
                )
                showEditor = true
            }
            Menu("Add example…") {
                ForEach(ExampleExtensions.catalog) { entry in
                    Button(entry.name) {
                        scriptStore.add(entry.make())
                    }
                    .help(entry.summary)
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            if let script = editingScript {
                NavigationStack {
                    UserScriptEditorView(
                    script: script,
                    onSave: { updated in
                        if scriptStore.scripts.contains(where: { $0.id == updated.id }) {
                            scriptStore.update(updated)
                        } else {
                            scriptStore.add(updated)
                        }
                        showEditor = false
                        editingScript = nil
                    },
                    onCancel: {
                        showEditor = false
                        editingScript = nil
                    }
                )
                }
            }
        }
        .onChange(of: showEditor) { _, visible in
            if !visible { editingScript = nil }
        }
    }

    private func scriptSubtitle(_ script: UserScript) -> String {
        let timing = script.injectAtDocumentStart ? "Start" : "End"
        let world = script.runInPageWorld ? "Page world" : "Isolated"
        let patterns = script.matchPatterns.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let scope: String
        if patterns.isEmpty {
            scope = "All URLs"
        } else if patterns.count == 1 {
            scope = patterns[0]
        } else {
            scope = "\(patterns.count) patterns"
        }
        return "\(timing) · \(world) · \(scope)"
    }
}

private struct UserScriptEditorView: View {
    let script: UserScript
    let onSave: (UserScript) -> Void
    let onCancel: () -> Void
    @State private var name: String = ""
    @State private var scriptText: String = ""
    @State private var cssText: String = ""
    @State private var matchPatternsText: String = ""
    @State private var excludePatternsText: String = ""
    @State private var injectAtStart: Bool = false
    @State private var runInPageWorld: Bool = false

    var body: some View {
        Form {
            Section("Script") {
                TextField("Name", text: $name)
                Toggle("Inject at document start", isOn: $injectAtStart)
                Toggle("Run in page JavaScript world", isOn: $runInPageWorld)
                Text("Isolated is safer (default). Page world shares the site’s JS context—use only for scripts that must hook page globals.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $scriptText)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 140)
            }
            Section("User CSS") {
                TextEditor(text: $cssText)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 80)
                Text("Injected as a style element when the URL matches.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("URL patterns") {
                Text("Match patterns (Chrome-style, one per line). Leave empty for all URLs (*://*/*).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $matchPatternsText)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 72)
                Text("Exclude patterns (optional, one per line)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $excludePatternsText)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 56)
            }
            Section("Native bridge") {
                Text("From JavaScript: browser.runtime.sendNativeMessage(\"\(script.id.uuidString)\", { any: \"payload\" }). Messages appear in ExtensionNativeMessageBridge (for debugging or future features).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 460, minHeight: 520)
        .navigationTitle("Edit script")
        .onAppear {
            name = script.name
            scriptText = script.script
            cssText = script.css
            matchPatternsText = Self.lines(from: script.matchPatterns)
            excludePatternsText = Self.lines(from: script.excludePatterns)
            injectAtStart = script.injectAtDocumentStart
            runInPageWorld = script.runInPageWorld
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { onCancel() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    var s = script
                    s.name = name
                    s.script = scriptText
                    s.css = cssText
                    s.matchPatterns = Self.patternLines(matchPatternsText)
                    s.excludePatterns = Self.patternLines(excludePatternsText)
                    s.injectAtDocumentStart = injectAtStart
                    s.runInPageWorld = runInPageWorld
                    onSave(s)
                }
            }
        }
    }

    private static func lines(from patterns: [String]) -> String {
        patterns.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    private static func patternLines(_ text: String) -> [String] {
        text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

private struct PackagedExtensionsList: View {
    @State private var store = PackagedExtensionStore.shared

    var body: some View {
        VStack(alignment: .leading) {
            Text("Packaged extensions bundled with the app — enable or disable them here.")
                .font(.caption)
                .foregroundStyle(.secondary)
            List {
                ForEach(store.extensions) { ext in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ext.name)
                                .font(.system(size: 13, weight: .medium))
                            if let desc = ext.manifest.description {
                                Text(desc)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { store.extensions.first(where: { $0.id == ext.id })?.isEnabled ?? false },
                            set: { newValue in store.setEnabled(ext.id, newValue) }
                        ))
                        .labelsHidden()
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.inset)
            .frame(minHeight: 80, maxHeight: 240)
            HStack {
                Button("Reload packaged extensions") {
                    PackagedExtensionStore.shared.reload()
                }
            }
        }
    }
}

#Preview {
    SettingsView(settings: BrowserSettings.shared)
        .frame(width: 480, height: 500)
}

