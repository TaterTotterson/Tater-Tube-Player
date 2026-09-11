import SwiftUI
import UIKit

struct ArtworkView: View {
    @EnvironmentObject private var store: PlayerStore

    let remoteValue: String?
    let demoName: String?
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color.white.opacity(0.035)

            if let demoName, let bundled = BundledImageView.load(demoName) {
                Image(uiImage: bundled)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity.animation(.easeOut(duration: 0.22)))
            } else {
                Image(systemName: "film.stack")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(TaterTheme.secondaryText.opacity(0.65))
            }
        }
        .clipped()
        .task(id: remoteValue) {
            image = nil
            guard let remoteValue, !remoteValue.isEmpty else { return }
            if let cached = ArtworkMemoryCache.shared.image(for: remoteValue) {
                image = cached
                return
            }
            if let data = try? await store.artworkData(for: remoteValue),
               let loaded = UIImage(data: data) {
                ArtworkMemoryCache.shared.insert(loaded, for: remoteValue)
                image = loaded
            }
        }
    }
}

@MainActor
private final class ArtworkMemoryCache {
    static let shared = ArtworkMemoryCache()

    private let images = NSCache<NSString, UIImage>()

    private init() {
        images.countLimit = 300
        images.totalCostLimit = 320 * 1024 * 1024
    }

    func image(for key: String) -> UIImage? {
        images.object(forKey: key as NSString)
    }

    func insert(_ image: UIImage, for key: String) {
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        images.setObject(image, forKey: key as NSString, cost: cost)
    }
}

struct BundledImageView: View {
    let name: String

    var body: some View {
        if let image = Self.load(name) {
            Image(uiImage: image)
                .resizable()
        } else {
            Color.clear
        }
    }

    static func load(_ name: String) -> UIImage? {
        guard let path = Bundle.main.path(forResource: name, ofType: "png") else { return nil }
        return UIImage(contentsOfFile: path)
    }
}
