//
//  Bookmark.swift
//  BrowseyReloaded
//
//  Created by Jacob Ferrari on 8/2/2026.
//

import SwiftUI

struct Bookmark: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    private var urlString: String

    var url: URL {
        get { URL(string: urlString) ?? URL(string: "about:blank")! }
        set { urlString = newValue.absoluteString }
    }

    init(id: UUID = UUID(), title: String, url: URL) {
        self.id = id
        self.title = title
        self.urlString = url.absoluteString
    }
}

@Observable
final class BookmarkStore {
    private(set) var bookmarks: [Bookmark] = []
    private let key = "BrowseyReloaded.Bookmarks"

    init() {
        load()
    }

    func add(title: String, url: URL) {
        guard !contains(url: url) else { return }
        let bookmark = Bookmark(title: title, url: url)
        bookmarks.insert(bookmark, at: 0)
        save()
    }

    func remove(_ bookmark: Bookmark) {
        bookmarks.removeAll { $0.id == bookmark.id }
        save()
    }

    func remove(id: UUID) {
        bookmarks.removeAll { $0.id == id }
        save()
    }

    func contains(url: URL) -> Bool {
        let normalized = url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return bookmarks.contains { b in
            let bNormalized = b.url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return bNormalized == normalized || b.url == url
        }
    }

    func bookmark(for url: URL) -> Bookmark? {
        let normalized = url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return bookmarks.first { b in
            let bNormalized = b.url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return bNormalized == normalized || b.url == url
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Bookmark].self, from: data) else { return }
        bookmarks = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(bookmarks) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
