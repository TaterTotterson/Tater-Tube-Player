import Foundation
@preconcurrency import TVServices

final class ContentProvider: TVTopShelfContentProvider {
    private let appGroupIdentifier = "group.com.tatertotterson.TaterTubePlayer"
    private let snapshotFilename = "continue-watching.json"
    private let storageDirectoryName = "TaterTubeTopShelf"
    private let artworkDirectoryName = "TopShelfArtwork"

    override func loadTopShelfContent() async -> (any TVTopShelfContent)? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else { return nil }

        let storageDirectory = containerURL
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Caches", isDirectory: true)
            .appendingPathComponent(storageDirectoryName, isDirectory: true)
        guard
        let data = try? Data(contentsOf: storageDirectory.appendingPathComponent(snapshotFilename)),
        let snapshot = try? JSONDecoder().decode(TopShelfSnapshot.self, from: data),
        !snapshot.items.isEmpty
        else { return nil }

        let artworkDirectory = storageDirectory.appendingPathComponent(
            artworkDirectoryName,
            isDirectory: true
        )
        let items = snapshot.items.compactMap { entry -> TVTopShelfSectionedItem? in
            let artworkURL = artworkDirectory.appendingPathComponent(entry.artworkFilename)
            guard FileManager.default.fileExists(atPath: artworkURL.path) else { return nil }

            let item = TVTopShelfSectionedItem(identifier: entry.identifier)
            item.title = entry.subtitle.map { "\(entry.title)  •  \($0)" } ?? entry.title
            item.imageShape = .poster
            item.playbackProgress = min(max(entry.progress, 0), 1)
            item.setImageURL(artworkURL, for: [.screenScale1x, .screenScale2x])
            if let displayURL = URL(string: entry.displayURL) {
                item.displayAction = TVTopShelfAction(url: displayURL)
            }
            if let playURL = URL(string: entry.playURL) {
                item.playAction = TVTopShelfAction(url: playURL)
            }
            return item
        }

        guard !items.isEmpty else { return nil }
        let section = TVTopShelfItemCollection(items: items)
        section.title = "Continue Watching"
        return TVTopShelfSectionedContent(sections: [section])
    }
}

private struct TopShelfSnapshot: Decodable {
    let items: [TopShelfEntry]
}

private struct TopShelfEntry: Decodable {
    let identifier: String
    let title: String
    let subtitle: String?
    let progress: Double
    let artworkFilename: String
    let displayURL: String
    let playURL: String
}
