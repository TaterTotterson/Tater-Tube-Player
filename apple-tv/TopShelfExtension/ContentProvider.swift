import Foundation
@preconcurrency import TVServices

final class ContentProvider: TVTopShelfContentProvider {
    override func loadTopShelfContent() async -> (any TVTopShelfContent)? {
        // Returning no dynamic content lets tvOS display the dedicated static
        // Top Shelf artwork from the app's brand assets without media cards.
        nil
    }
}
