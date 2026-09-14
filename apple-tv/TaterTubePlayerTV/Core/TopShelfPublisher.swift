import CryptoKit
import Foundation
import TVServices

enum TopShelfPublisher {
    static let appGroupIdentifier = "group.com.tatertotterson.TaterTubePlayer"

    private static let snapshotFilename = "continue-watching.json"
    private static let storageDirectoryName = "TaterTubeTopShelf"
    private static let artworkDirectoryName = "TopShelfArtwork"

    static func publish(
        items: [MediaItem],
        client: APIClient?,
        isDemo: Bool
    ) async {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else { return }

        let storageDirectory = containerURL
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Caches", isDirectory: true)
            .appendingPathComponent(storageDirectoryName, isDirectory: true)
        let artworkDirectory = storageDirectory.appendingPathComponent(
            artworkDirectoryName,
            isDirectory: true
        )
        do {
            try FileManager.default.createDirectory(
                at: artworkDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            return
        }

        var entries: [TopShelfEntry] = []
        var retainedArtwork = Set<String>()

        for item in items.prefix(12) {
            guard let artworkFilename = await cacheArtwork(
                for: item,
                client: client,
                isDemo: isDemo,
                in: artworkDirectory
            ) else { continue }

            retainedArtwork.insert(artworkFilename)
            entries.append(
                TopShelfEntry(
                    identifier: item.id,
                    title: item.title,
                    subtitle: item.subtitle ?? item.date,
                    progress: min(max((item.progressPercent ?? 0) / 100, 0), 1),
                    artworkFilename: artworkFilename,
                    displayURL: deepLink(for: item.id, shouldPlay: false),
                    playURL: deepLink(for: item.id, shouldPlay: true)
                )
            )
        }

        let snapshot = TopShelfSnapshot(items: entries)
        let snapshotURL = storageDirectory.appendingPathComponent(snapshotFilename)
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: snapshotURL, options: .atomic)
        }

        removeStaleArtwork(in: artworkDirectory, retaining: retainedArtwork)
        TVTopShelfContentProvider.topShelfContentDidChange()
    }

    static func clear() {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else { return }
        let storageDirectory = containerURL
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Caches", isDirectory: true)
            .appendingPathComponent(storageDirectoryName, isDirectory: true)
        try? FileManager.default.removeItem(at: storageDirectory)
        TVTopShelfContentProvider.topShelfContentDidChange()
    }

    private static func cacheArtwork(
        for item: MediaItem,
        client: APIClient?,
        isDemo: Bool,
        in directory: URL
    ) async -> String? {
        if isDemo,
           let demoName = item.demoArtworkName,
           let bundledURL = Bundle.main.url(forResource: demoName, withExtension: "png"),
           let data = try? Data(contentsOf: bundledURL) {
            return writeArtwork(data, key: "demo:\(demoName)", to: directory)
        }

        guard let value = preferredArtwork(for: item), !value.isEmpty else { return nil }
        let stem = digest(value)
        if let existing = existingArtwork(withStem: stem, in: directory) {
            return existing.lastPathComponent
        }
        guard let client else { return nil }
        do {
            let data = try await client.artworkData(from: value)
            return writeArtwork(data, key: value, to: directory)
        } catch {
            return nil
        }
    }

    private static func preferredArtwork(for item: MediaItem) -> String? {
        [item.poster, item.seriesPoster, item.seasonPoster, item.episodeStill, item.backdrop]
            .compactMap { $0 }
            .first { !$0.isEmpty }
    }

    private static func writeArtwork(_ data: Data, key: String, to directory: URL) -> String? {
        guard !data.isEmpty else { return nil }
        let filename = "\(digest(key)).\(fileExtension(for: data))"
        let destination = directory.appendingPathComponent(filename)
        if !FileManager.default.fileExists(atPath: destination.path) {
            do {
                try data.write(to: destination, options: .atomic)
            } catch {
                return nil
            }
        }
        return filename
    }

    private static func existingArtwork(withStem stem: String, in directory: URL) -> URL? {
        let extensions = ["jpg", "png", "webp", "img"]
        return extensions
            .map { directory.appendingPathComponent("\(stem).\($0)") }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private static func fileExtension(for data: Data) -> String {
        let bytes = [UInt8](data.prefix(12))
        if bytes.starts(with: [0xFF, 0xD8, 0xFF]) { return "jpg" }
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "png" }
        if bytes.count >= 12,
           String(bytes: bytes[0..<4], encoding: .ascii) == "RIFF",
           String(bytes: bytes[8..<12], encoding: .ascii) == "WEBP" {
            return "webp"
        }
        return "img"
    }

    private static func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func deepLink(for identifier: String, shouldPlay: Bool) -> String {
        var components = URLComponents()
        components.scheme = "tatertubeplayer"
        components.host = "continue"
        components.queryItems = [
            URLQueryItem(name: "id", value: identifier),
            URLQueryItem(name: "action", value: shouldPlay ? "play" : "display")
        ]
        return components.url?.absoluteString ?? "tatertubeplayer://continue"
    }

    private static func removeStaleArtwork(in directory: URL, retaining filenames: Set<String>) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return }
        for file in files where !filenames.contains(file.lastPathComponent) {
            try? FileManager.default.removeItem(at: file)
        }
    }
}

private struct TopShelfSnapshot: Codable {
    let items: [TopShelfEntry]
}

private struct TopShelfEntry: Codable {
    let identifier: String
    let title: String
    let subtitle: String?
    let progress: Double
    let artworkFilename: String
    let displayURL: String
    let playURL: String
}
