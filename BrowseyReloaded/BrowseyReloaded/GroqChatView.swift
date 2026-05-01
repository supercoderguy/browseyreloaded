//
//  GroqChatView.swift
//  BrowseyReloaded
//
//  Created by Jacob Ferrari on 8/2/2026.
//

import SwiftUI

private enum BrowseyDesign {
    static let accent = Color(red: 0.38, green: 0.42, blue: 0.93)
    static let accentMuted = Color(red: 0.38, green: 0.42, blue: 0.93).opacity(0.2)
}

struct GroqChatMessage: Identifiable {
    let id = UUID()
    let role: String // "user" | "model"
    let text: String
}

/// Holds Groq chat state so it outlives sheet content recreation.
@Observable
final class GroqChatViewModel {
    let groqService = GroqService()
    var messages: [GroqChatMessage] = []
    var inputText = ""
    var apiKeyInput = ""
    /// Current page text injected from the browser. Set externally by ContentView.
    var pageContent: String? = nil
    var pageURL: String? = nil
    var isLoadingPageContent = false

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, groqService.hasValidAPIKey else { return }
        inputText = ""
        let userMsg = GroqChatMessage(role: "user", text: text)
        messages.append(userMsg)

        let history = messages.dropLast().map { (role: $0.role, text: $0.text) }
        let prompt = text
        let systemPrompt = buildSystemPrompt()
        Task {
            do {
                let response = try await groqService.generateContent(
                    prompt: prompt,
                    history: history,
                    systemPrompt: systemPrompt
                )
                await MainActor.run {
                    messages.append(GroqChatMessage(role: "model", text: response))
                }
            } catch {
                await MainActor.run {
                    groqService.lastError = error.localizedDescription
                    messages.append(GroqChatMessage(role: "model", text: "Error: \(error.localizedDescription)"))
                }
            }
        }
    }

    private func buildSystemPrompt() -> String? {
        guard let content = pageContent, !content.isEmpty else { return nil }
        let url = pageURL.map { " (\($0))" } ?? ""
        let truncated = content.count > 12000 ? String(content.prefix(12000)) + "\n...[truncated]" : content
        return "You are a helpful browser assistant. The user is currently viewing a webpage\(url). Here is the page content:\n\n\(truncated)\n\nAnswer questions about this page or help the user with anything else."
    }

    func saveAPIKey() {
        let key = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty {
            groqService.apiKey = key
            apiKeyInput = ""
        }
    }
}

// MARK: - Sidebar View (replaces sheet)

struct GroqChatView: View {
    var accent: Color? = nil
    @Bindable var viewModel: GroqChatViewModel
    /// Called when the user wants to close the sidebar
    var onClose: (() -> Void)? = nil
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isInputFocused: Bool

    private var accentColor: Color { accent ?? BrowseyDesign.accent }

    private var surface: Color {
        colorScheme == .dark
            ? Color(red: 0.12, green: 0.12, blue: 0.14)
            : Color(red: 0.96, green: 0.96, blue: 0.98)
    }

    private var surfaceElevated: Color {
        colorScheme == .dark
            ? Color(red: 0.16, green: 0.16, blue: 0.18)
            : Color(red: 0.92, green: 0.92, blue: 0.95)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if !viewModel.groqService.hasValidAPIKey {
                apiKeySection
            } else {
                pageContextBanner
            }
            messagesSection
            inputSection
        }
        .background(surface)
        .frame(minWidth: 300, maxWidth: 400)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(accentColor)
            Text("Groq")
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            if viewModel.groqService.hasValidAPIKey {
                Picker("Model", selection: Binding(
                    get: { viewModel.groqService.selectedModelId },
                    set: { viewModel.groqService.selectedModelId = $0 }
                )) {
                    ForEach(GroqService.availableModels, id: \.id) { model in
                        Text(model.name).tag(model.id)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 140)
                .pickerStyle(.menu)

                Button("Clear") { viewModel.messages = [] }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
            }
            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(surfaceElevated.opacity(0.8))
    }

    // MARK: Page context banner

    @ViewBuilder
    private var pageContextBanner: some View {
        HStack(spacing: 8) {
            if viewModel.isLoadingPageContent {
                ProgressView().scaleEffect(0.7)
                Text("Reading page…")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else if let content = viewModel.pageContent, !content.isEmpty {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(accentColor)
                Text("Page content loaded")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear") {
                    viewModel.pageContent = nil
                    viewModel.pageURL = nil
                }
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            } else {
                Image(systemName: "doc.text")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text("No page context")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(accentColor.opacity(viewModel.pageContent != nil ? 0.08 : 0.0))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color.primary.opacity(0.06)),
            alignment: .bottom
        )
    }

    // MARK: API key section

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("API Key")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            SecureField("Paste your Groq API key", text: $viewModel.apiKeyInput)
                .textFieldStyle(.plain)
                .padding(10)
                .background(surfaceElevated, in: RoundedRectangle(cornerRadius: 10))
                .onSubmit { viewModel.saveAPIKey() }
            if let err = viewModel.groqService.lastError {
                Text(err)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }
            if let groqURL = URL(string: "https://console.groq.com/keys") {
                Link("Get a key at console.groq.com/keys", destination: groqURL)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Button("Save API Key") { viewModel.saveAPIKey() }
                .buttonStyle(.borderedProminent)
                .tint(accentColor)
        }
        .padding(14)
        .background(surfaceElevated.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        .padding(14)
    }

    // MARK: Messages

    private var messagesSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if viewModel.messages.isEmpty && viewModel.groqService.hasValidAPIKey {
                        VStack(spacing: 6) {
                            Text("Ask Groq anything.")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            if viewModel.pageContent != nil {
                                Text("Page context is active — ask about this page!")
                                    .font(.system(size: 11))
                                    .foregroundStyle(accentColor.opacity(0.8))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                    }
                    ForEach(viewModel.messages) { msg in
                        messageBubble(msg)
                    }
                    if viewModel.groqService.isGenerating {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.7)
                            Text("Thinking…")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(14)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                if let last = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func messageBubble(_ msg: GroqChatMessage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if msg.role == "user" { Spacer(minLength: 30) }
            else {
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                    .foregroundStyle(accentColor)
                    .padding(.top, 2)
            }
            Text(msg.text)
                .textSelection(.enabled)
                .font(.system(size: 12))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    msg.role == "user" ? accentColor.opacity(0.18) : surfaceElevated,
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .frame(maxWidth: .infinity, alignment: msg.role == "user" ? .trailing : .leading)
            if msg.role == "model" { Spacer(minLength: 30) }
        }
    }

    // MARK: Input

    private var inputSection: some View {
        HStack(spacing: 10) {
            TextField("Ask Groq…", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .focused($isInputFocused)
                .lineLimit(1...5)
                .font(.system(size: 13))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(surfaceElevated, in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(accentColor.opacity(0.25), lineWidth: 1)
                )
                .onSubmit { viewModel.sendMessage() }

            Button(action: { viewModel.sendMessage() }) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 13))
            }
            .buttonStyle(.glassProminent)
            .tint(accentColor)
            .disabled(
                viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || viewModel.groqService.isGenerating
                || !viewModel.groqService.hasValidAPIKey
            )
        }
        .padding(14)
        .background(surface)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color.primary.opacity(0.06)),
            alignment: .top
        )
    }
}

#Preview {
    HStack {
        Spacer()
        GroqChatView(viewModel: GroqChatViewModel())
    }
    .frame(width: 700, height: 520)
}
