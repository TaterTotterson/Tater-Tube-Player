import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var store: PlayerStore

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 54) {
                HStack(spacing: 24) {
                    libraryButton("All Movies", icon: "film.fill")
                    libraryButton("All TV Shows", icon: "tv.and.mediabox.fill")
                }
                .padding(30)
                .taterGlass(cornerRadius: 30)

                if let items = store.home?.continueWatching, !items.isEmpty {
                    MediaShelf(title: "Continue Watching", items: items)
                }
                if let items = store.home?.recentlyAdded, !items.isEmpty {
                    MediaShelf(title: "Recently Added", items: items)
                }
            }
            .padding(.horizontal, 78)
            .padding(.top, 42)
            .padding(.bottom, 110)
        }
    }

    private func libraryButton(_ title: String, icon: String) -> some View {
        Button { } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 29, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 72)
        }
        .buttonStyle(.borderedProminent)
        .tint(TaterTheme.orange.opacity(0.78))
    }
}
