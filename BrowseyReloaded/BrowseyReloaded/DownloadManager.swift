//
//  DownloadManager.swift
//  BrowseyReloaded
//
//  Simple download manager using URLSessionDownloadTask. Tracks
//  downloads, progress, and stores completed files in the user's
//  Downloads folder. Observable for SwiftUI.
//

import Foundation
import AppKit

enum DownloadState: String, Codable {
    case queued
    case downloading
    case completed
    case failed
    case canceled
}

struct DownloadItem: Identifiable {
    let id: UUID
    let url: URL
    var filename: String
    var state: DownloadState
    var progress: Double // 0.0 - 1.0
    var destination: URL?
    var errorMessage: String?
    let createdAt: Date
}

@Observable
final class DownloadManager: NSObject {
    static let shared = DownloadManager()

    private override init() {
        super.init()
        let cfg = URLSessionConfiguration.default
        cfg.httpCookieStorage = HTTPCookieStorage.shared
        cfg.httpShouldSetCookies = true
        session = URLSession(configuration: cfg, delegate: self, delegateQueue: OperationQueue.main)
    }

    private var session: URLSession!

    private(set) var items: [DownloadItem] = [] {
        didSet {}
    }

    private var tasks: [Int: UUID] = [:]
    private var tasksByUUID: [UUID: URLSessionDownloadTask] = [:]

    func startDownload(from url: URL, suggestedFilename: String? = nil) {
        let id = UUID()
        let filename = suggestedFilename ?? url.lastPathComponent
        var item = DownloadItem(id: id, url: url, filename: filename.isEmpty ? "download" : filename, state: .queued, progress: 0.0, destination: nil, errorMessage: nil, createdAt: Date())
        items.insert(item, at: 0)

        let task = session.downloadTask(with: url)
        tasks[task.taskIdentifier] = id
        tasksByUUID[id] = task
        item.state = .downloading
        updateItem(item)
        task.resume()
    }

    func cancel(_ id: UUID) {
        if let task = tasksByUUID[id] {
            task.cancel()
        }
        if var item = items.first(where: { $0.id == id }) {
            item.state = .canceled
            updateItem(item)
        }
    }

    func reveal(_ id: UUID) {
        guard let item = items.first(where: { $0.id == id }), let dest = item.destination else { return }
        NSWorkspace.shared.activateFileViewerSelecting([dest])
    }

    func open(_ id: UUID) {
        guard let item = items.first(where: { $0.id == id }), let dest = item.destination else { return }
        NSWorkspace.shared.open(dest)
    }

    func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
    }

    private func updateItem(_ newItem: DownloadItem) {
        if let i = items.firstIndex(where: { $0.id == newItem.id }) {
            items[i] = newItem
        }
    }
}

// MARK: - URLSessionDownloadDelegate
extension DownloadManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let id = tasks[downloadTask.taskIdentifier], var item = items.first(where: { $0.id == id }) else { return }
        let fm = FileManager.default
        let downloads = fm.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? fm.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        var dest = downloads.appendingPathComponent(item.filename)
        var counter = 1
        while fm.fileExists(atPath: dest.path) {
            let ext = dest.pathExtension
            let base = dest.deletingPathExtension().lastPathComponent
            let newName = "\(base) (\(counter))" + (ext.isEmpty ? "" : ".\(ext)")
            dest = downloads.appendingPathComponent(newName)
            counter += 1
        }
        do {
            try fm.moveItem(at: location, to: dest)
            item.destination = dest
            item.state = .completed
            item.progress = 1.0
            updateItem(item)
        } catch {
            item.state = .failed
            item.errorMessage = error.localizedDescription
            updateItem(item)
        }
        tasks.removeValue(forKey: downloadTask.taskIdentifier)
        tasksByUUID.removeValue(forKey: id)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let id = tasks[downloadTask.taskIdentifier], var item = items.first(where: { $0.id == id }) else { return }
        if totalBytesExpectedToWrite > 0 {
            item.progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        } else {
            item.progress = 0
        }
        item.state = .downloading
        updateItem(item)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let id = tasks[task.taskIdentifier], var item = items.first(where: { $0.id == id }) else { return }
        if let err = error {
            item.state = .failed
            item.errorMessage = err.localizedDescription
            updateItem(item)
        }
        tasks.removeValue(forKey: task.taskIdentifier)
        tasksByUUID.removeValue(forKey: id)
    }
}
