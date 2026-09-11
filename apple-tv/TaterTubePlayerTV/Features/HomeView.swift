import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: PlayerStore
    @Binding var selectedTab: Int

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 54) {
                    hero

                    if let items = store.home?.continueWatching, !items.isEmpty {
                        MediaShelf(
                            title: "Continue Watching",
                            items: items,
                            destination: continueWatchingLocation
                        )
                    }

                    if let channels = store.home?.liveChannels, !channels.isEmpty {
                        liveShelf(channels)
                    }

                    if let items = store.home?.recentlyAdded, !items.isEmpty {
                        MediaShelf(
                            title: "Recently Added",
                            items: items,
                            destination: recentlyAddedLocation
                        )
                    }
                }
                .padding(.horizontal, 78)
                .padding(.top, 42)
                .padding(.bottom, 110)
            }
            .refreshable { await store.refreshHome() }
            .navigationDestination(for: LibraryLocation.self) { location in
                LibraryCollectionView(location: location)
            }
        }
    }

    private var hero: some View {
        HStack(spacing: 54) {
            VStack(alignment: .leading, spacing: 18) {
                Text(store.home?.hero?.eyebrow ?? greeting)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .tracking(2.5)
                    .foregroundStyle(TaterTheme.orange)

                Text(store.home?.hero?.message ?? "Everything good, right where you left it.")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                HStack(spacing: 12) {
                    Circle()
                        .fill(store.isDemo ? Color.yellow : Color.green)
                        .frame(width: 11, height: 11)
                    Text(store.isDemo ? "DEMO MODE" : "\(store.home?.serverName ?? "Tater Tube Server") ONLINE")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(TaterTheme.secondaryText)
                }

                HStack(spacing: 14) {
                    if store.home?.capabilities.tubeTV == true {
                        Button { selectedTab = 2 } label: {
                            Label("Watch Live", systemImage: "play.fill")
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(TaterTheme.orange)
                    }

                    Button { selectedTab = 1 } label: {
                        Label("Browse Library", systemImage: "rectangle.stack.fill")
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.white.opacity(0.15))

                    if store.home?.capabilities.newznab == true {
                        Button { selectedTab = 3 } label: {
                            Label("Discover", systemImage: "sparkles.tv.fill")
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.white.opacity(0.15))
                    }

                    if store.home?.capabilities.taterLink == true {
                        Button { selectedTab = 4 } label: {
                            Label("Tater Picks", systemImage: "wand.and.stars")
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.white.opacity(0.15))
                    }
                }
                .font(.system(size: 20, weight: .bold, design: .rounded))
            }

            Spacer(minLength: 20)

            BundledImageView(name: "tater-hero-remote")
                .scaledToFit()
                .frame(width: 300, height: 260)
        }
        .padding(.horizontal, 55)
        .padding(.vertical, 35)
        .frame(maxWidth: .infinity, minHeight: 320)
        .taterGlass(cornerRadius: 36)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "GOOD MORNING" }
        if hour < 18 { return "GOOD AFTERNOON" }
        return "GOOD EVENING"
    }

    private func liveShelf(_ channels: [LiveChannel]) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Live on Tater Tube")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 28) {
                    ForEach(channels) { channel in
                        Button {
                            Task { await store.play(channel) }
                        } label: { LiveChannelCardView(channel: channel) }
                            .buttonStyle(.card)
                    }

                    Button { selectedTab = 2 } label: {
                        ShelfDestinationCard(title: "Open Guide", icon: "list.bullet.rectangle.fill")
                    }
                    .buttonStyle(.card)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
            .contentMargins(.horizontal, -18, for: .scrollContent)
        }
    }

    private var continueWatchingLocation: LibraryLocation {
        if let row = store.libraryRows.first(where: {
            $0.entry.type?.lowercased() == "continue"
        }) {
            return LibraryLocation(entry: row.entry)
        }
        return LibraryLocation(
            categoryID: "",
            title: "Continue Watching",
            continueWatching: true
        )
    }

    private var recentlyAddedLocation: LibraryLocation {
        if let row = store.libraryRows.first(where: {
            $0.entry.id.lowercased() == "local-discover:recent"
        }) {
            return LibraryLocation(entry: row.entry)
        }
        return LibraryLocation(
            categoryID: "local-discover:recent",
            title: "Recently Added"
        )
    }
}

struct MediaShelf: View {
    @EnvironmentObject private var store: PlayerStore

    let title: String
    let items: [MediaItem]
    let destination: LibraryLocation?

    init(title: String, items: [MediaItem], destination: LibraryLocation? = nil) {
        self.title = title
        self.items = items
        self.destination = destination
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(title)
                .font(.system(size: 34, weight: .bold, design: .rounded))

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 28) {
                    ForEach(items) { item in
                        Button {
                            store.openDetails(for: item)
                        } label: { MediaCardView(item: item) }
                            .buttonStyle(.card)
                    }

                    if let destination {
                        NavigationLink(value: destination) {
                            ShelfDestinationCard(title: "See All", icon: "arrow.right.circle.fill")
                        }
                        .buttonStyle(.card)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
            .contentMargins(.horizontal, -18, for: .scrollContent)
        }
    }
}

private struct ShelfDestinationCard: View {
    let title: String
    let icon: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 58, weight: .medium))
            Text(title)
                .font(.system(size: 23, weight: .bold, design: .rounded))
        }
        .foregroundStyle(.white)
        .frame(width: 190, height: 365)
        .taterGlass(cornerRadius: 24, interactive: true)
    }
}
