//
//  GroqService.swift
//  BrowseyReloaded
//
//  Created by Jacob Ferrari on 8/2/2026.
//

import Foundation
import AppKit
internal import WebKit

/// Calls Groq API (OpenAI-compatible chat completions). API key is stored in UserDefaults.
@MainActor
@Observable
final class GroqService {

    static let apiKeyUserDefaultsKey = "BrowseyReloaded.GroqAPIKey"
    static let modelIdUserDefaultsKey = "BrowseyReloaded.GroqModelId"
    private static let endpoint = "https://api.groq.com/openai/v1/chat/completions"

    /// Production and preview models suitable for chat (from Groq docs).
    static let availableModels: [(id: String, name: String)] = [
        ("kimi-k2-0905", "Kimi-K2 0905 (function calling, tool use)"),
        ("openai/gpt-oss-120b", "GPT-OSS 120B (open-weight MoE, top-tier reasoning)"),
        ("openai/gpt-oss-20b", "GPT-OSS 20B (compact, strong context)") ,
        ("llama-3.3-70b-versatile", "Llama 3.3 70B Versatile (low-cost, balanced dialogue)"),
        ("meta-llama/llama-4-maverick-17b-128e-instruct", "Llama 4 Maverick 17B"),
        ("meta-llama/llama-4-scout-17b-16e-instruct", "Llama 4 Scout 17B"),
        ("qwen/qwen3-32b", "Qwen3 32B"),
        ("compound-beta", "Compound Beta (Groq exclusive, orchestration)")
    ]

    private(set) var isGenerating = false
    var lastError: String?

    var apiKey: String {
        get { UserDefaults.standard.string(forKey: Self.apiKeyUserDefaultsKey) ?? "" }
        set {
            UserDefaults.standard.set(
                newValue.trimmingCharacters(in: .whitespacesAndNewlines),
                forKey: Self.apiKeyUserDefaultsKey
            )
            lastError = nil
        }
    }

    var selectedModelId: String {
        get {
            let stored = UserDefaults.standard.string(forKey: Self.modelIdUserDefaultsKey)
            if let s = stored,
               Self.availableModels.contains(where: { $0.id == s }) {
                return s
            }
            return Self.availableModels[0].id
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.modelIdUserDefaultsKey)
        }
    }

    var hasValidAPIKey: Bool {
        !apiKey.isEmpty
    }
    
    var webView: WKWebView!

    /// Send a prompt with optional conversation history; returns the assistant's text reply.
    func generateContent(
        prompt: String,
        history: [(role: String, text: String)] = [],
        systemPrompt: String? = nil
    ) async throws -> String {

        lastError = nil
        isGenerating = true
        defer { isGenerating = false }

        guard hasValidAPIKey else {
            lastError = "Please set your Groq API key in the chat."
            throw GroqError.missingAPIKey
        }

        let url = URL(string: Self.endpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var messages: [[String: String]] = []
        // Inject system prompt first if provided
        if let systemPrompt {
            messages.append(["role": "system", "content": systemPrompt])
        }
        for (role, text) in history {
            messages.append([
                "role": role == "user" ? "user" : "assistant",
                "content": text
            ])
        }
        messages.append([
            "role": "user",
            "content": prompt
        ])

        let body: [String: Any] = [
            "model": selectedModelId,
            "messages": messages,
            "temperature": 0.7,
            "max_tokens": 2048
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            lastError = "Invalid response"
            throw GroqError.invalidResponse
        }

        guard http.statusCode == 200 else {
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let message = json?["error"] as? [String: Any]

            let errorText = message?["message"] as? String ?? "HTTP \(http.statusCode)"
            lastError = errorText
            throw GroqError.apiError(errorText)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard
            let choices = json?["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any],
            let text = message["content"] as? String
        else {
            lastError = "Could not parse response"
            throw GroqError.invalidResponse
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Send a prompt with an attached file to the AI. The file is base64-encoded and included in the prompt.
    func generateContentWithFile(
        prompt: String,
        fileURL: URL,
        history: [(role: String, text: String)] = []
    ) async throws -> String {
        
        lastError = nil
        isGenerating = true
        defer { isGenerating = false }
        
        guard hasValidAPIKey else {
            lastError = "Please set your Groq API key in the chat."
            throw GroqError.missingAPIKey
        }
        
        let fileData: Data
        do {
            fileData = try Data(contentsOf: fileURL)
        } catch {
            lastError = "Failed to read file: \(error.localizedDescription)"
            throw error
        }
        
        let base64File = fileData.base64EncodedString()
        let filename = fileURL.lastPathComponent
        let filePrompt = "\(prompt)\n\nAttached file: \(filename) (base64-encoded):\n\(base64File)"
        
        return try await generateContent(prompt: filePrompt, history: history)
    }

    /// Presents a native file picker, lets the user select a file, and sends the selected file to the AI.
    func pickFileAndSendToAI(prompt: String, history: [(role: String, text: String)] = []) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                panel.canChooseFiles = true
                panel.begin { response in
                    if response == .OK, let url = panel.url {
                        Task {
                            do {
                                let result = try await self.generateContentWithFile(prompt: prompt, fileURL: url, history: history)
                                continuation.resume(returning: result)
                            } catch {
                                continuation.resume(throwing: error)
                            }
                        }
                    } else {
                        continuation.resume(throwing: GroqError.invalidResponse)
                    }
                }
            }
        }
    }
    
    /// Enables drag-and-drop support for files onto the WKWebView.
    func enableFileDragDrop() {
        guard let webView = webView else { return }
        let dragDropView = DragDropView(frame: webView.bounds, groqService: self)
        dragDropView.autoresizingMask = [.width, .height]
        
        // Remove webView from its superview and add dragDropView in its place
        if let superview = webView.superview {
            webView.removeFromSuperview()
            dragDropView.addSubview(webView)
            webView.frame = dragDropView.bounds
            webView.autoresizingMask = [.width, .height]
            superview.addSubview(dragDropView)
            dragDropView.frame = webView.frame
            dragDropView.autoresizingMask = [.width, .height]
        }
    }
    
    /// A helper NSView subclass that acts as an NSDraggingDestination for files.
    private class DragDropView: NSView {
        weak var groqService: GroqService?
        
        init(frame frameRect: NSRect, groqService: GroqService) {
            self.groqService = groqService
            super.init(frame: frameRect)
            registerForDraggedTypes([.fileURL])
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            registerForDraggedTypes([.fileURL])
        }
        
        override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
            if checkDraggingContainsFile(sender) {
                return .copy
            }
            return []
        }
        
        override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
            return checkDraggingContainsFile(sender)
        }
        
        override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
            guard let groqService = groqService else { return false }
            let pasteboard = sender.draggingPasteboard
            if let files = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], let fileURL = files.first {
                Task {
                    do {
                        _ = try await groqService.generateContentWithFile(prompt: "File dropped:", fileURL: fileURL)
                    } catch {
                        // Handle error if needed
                    }
                }
                return true
            }
            return false
        }
        
        private func checkDraggingContainsFile(_ sender: NSDraggingInfo) -> Bool {
            let pasteboard = sender.draggingPasteboard
            if let types = pasteboard.types, types.contains(.fileURL) {
                return true
            }
            return false
        }
    }
}

enum GroqError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API key not set."
        case .invalidResponse:
            return "Invalid response from API."
        case .apiError(let msg):
            return msg
        }
    }
}

