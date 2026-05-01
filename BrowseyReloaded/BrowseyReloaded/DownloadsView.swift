//
//  DownloadsView.swift
//  BrowseyReloaded
//
//  SwiftUI view for showing current downloads and actions.
//

import SwiftUI

struct DownloadsView: View {
    @State private var manager = DownloadManager.shared

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Downloads")
                    .font(.title2)
                    .bold()
                Spacer()
                Button("Close") { dismiss() }
            }
            .padding(.horizontal)

            List {
                ForEach(manager.items) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.filename)
                                .font(.system(size: 13, weight: .medium))
                            Text(item.url.absoluteString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        if item.state == .downloading {
                            ProgressView(value: item.progress)
                                .frame(width: 160)
                        } else if item.state == .completed {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        } else if item.state == .failed {
                            Image(systemName: "xmark.octagon.fill").foregroundStyle(.red)
                        }
                        VStack(spacing: 6) {
                            if item.state == .downloading {
                                Button("Cancel") { DownloadManager.shared.cancel(item.id) }
                            } else if item.state == .completed {
                                Button("Open") { DownloadManager.shared.open(item.id) }
                                Button("Reveal") { DownloadManager.shared.reveal(item.id) }
                            } else if item.state == .failed {
                                if let _ = item.destination {
                                    Button("Reveal") { DownloadManager.shared.reveal(item.id) }
                                }
                                Button("Remove") { DownloadManager.shared.remove(item.id) }
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 6)
                }
            }
            .frame(minWidth: 560, minHeight: 220)
        }
        .padding(.vertical)
    }
}

struct DownloadsView_Previews: PreviewProvider {
    static var previews: some View {
        DownloadsView()
    }
}
