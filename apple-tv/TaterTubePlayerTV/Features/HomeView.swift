import Combine
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: PlayerStore
    @Binding var selectedTab: Int
    @State private var navigationPath: [LibraryLocation] = []
    @State private var heroFocusRequest = 0
    @State private var heroClock = Date()

    private let heroClockTimer = Timer.publish(
        every: 60,
        on: .main,
        in: .common
    ).autoconnect()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 54) {
                        hero

                        if let items = store.home?.continueWatching, !items.isEmpty {
                            MediaShelf(
                                title: "Continue Watching",
                                items: items,
                                destination: continueWatchingLocation,
                                onNavigate: { navigationPath.append($0) }
                            )
                        }

                        if !homeLiveChannels.isEmpty {
                            liveShelf(homeLiveChannels)
                        }

                        if let items = store.home?.recentlyAdded, !items.isEmpty {
                            MediaShelf(
                                title: "Recently Added",
                                items: items,
                                destination: recentlyAddedLocation,
                                handlesRecentlyAddedShows: true,
                                onNavigate: { navigationPath.append($0) }
                            )
                        }
                    }
                    .padding(.horizontal, 78)
                    .padding(.top, 42)
                    .padding(.bottom, 110)
                    .id("home-scroll-top")
                }
                .refreshable {
                    await store.refreshHome()
                    if store.home?.capabilities.tubeTV == true {
                        await store.refreshLiveGuide()
                    }
                }
                .onChange(of: heroFocusRequest) { _, _ in
                    withAnimation(.easeOut(duration: 0.20)) {
                        scrollProxy.scrollTo("home-scroll-top", anchor: .top)
                    }
                }
            }
            .navigationDestination(for: LibraryLocation.self) { location in
                LibraryCollectionView(
                    location: location,
                    onNavigate: { navigationPath.append($0) }
                )
            }
        }
        .onAppear {
            heroClock = Date()
            Task {
                await store.refreshHome(
                    minimumInterval: 10,
                    reportErrors: false
                )
            }
        }
        .onReceive(heroClockTimer) { date in
            heroClock = date
            Task {
                await store.refreshHome(
                    minimumInterval: 55,
                    reportErrors: false
                )
            }
        }
    }

    private var hero: some View {
        HStack(spacing: 54) {
            VStack(alignment: .leading, spacing: 18) {
                Text(heroEyebrow)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .tracking(2.5)
                    .foregroundStyle(TaterTheme.orange)

                Text(heroMessage)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                HStack(spacing: 14) {
                    if store.home?.capabilities.tubeTV == true {
                        TaterActionButton(
                            action: { selectedTab = 2 },
                            onFocusChange: restoreHeroWhenFocused
                        ) {
                            Label("Watch Live", systemImage: "play.fill")
                                .foregroundStyle(.white)
                        }
                    }

                    TaterActionButton(
                        action: { selectedTab = 1 },
                        onFocusChange: restoreHeroWhenFocused
                    ) {
                        Label("Browse Library", systemImage: "rectangle.stack.fill")
                            .foregroundStyle(.white)
                    }

                    if store.home?.capabilities.newznab == true {
                        TaterActionButton(
                            action: { selectedTab = 3 },
                            onFocusChange: restoreHeroWhenFocused
                        ) {
                            Label("Discover", systemImage: "sparkles.tv.fill")
                                .foregroundStyle(.white)
                        }
                    }

                    if store.home?.capabilities.taterLink == true {
                        TaterActionButton(
                            action: { selectedTab = 4 },
                            onFocusChange: restoreHeroWhenFocused
                        ) {
                            Label("Tater Picks", systemImage: "wand.and.stars")
                                .foregroundStyle(.white)
                        }
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
        .focusSection()
    }

    private var homeLiveChannels: [LiveChannel] {
        if let channels = store.liveGuide?.channels, !channels.isEmpty {
            return channels
        }
        return store.home?.liveChannels ?? []
    }

    private func restoreHeroWhenFocused(_ focused: Bool) {
        if focused { heroFocusRequest += 1 }
    }

    private var heroEyebrow: String {
        let calendar = Calendar.current
        let weekday = heroClock.formatted(.dateTime.weekday(.wide)).uppercased()
        let hour = calendar.component(.hour, from: heroClock)
        let timeOfDay: String
        switch hour {
        case 5..<12:
            timeOfDay = "MORNING"
        case 12..<17:
            timeOfDay = "AFTERNOON"
        case 17..<22:
            timeOfDay = "EVENING"
        default:
            timeOfDay = "LATE NIGHT"
        }
        return "\(weekday) \(timeOfDay)"
    }

    private var heroMessage: String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: heroClock)
        let day = calendar.ordinality(of: .day, in: .year, for: heroClock) ?? 0
        let messages: [String]
        switch hour {
        case 5..<12:
            messages = [
                "Start the day with something good.",
                "Your morning watch is ready.",
                "Ease into something worth watching."
            ]
        case 12..<17:
            messages = [
                "Take a break with something good.",
                "There’s always time for one more.",
                "Your afternoon watch is ready."
            ]
        case 17..<22:
            messages = [
                "Settle in and press play.",
                "Your next watch starts here.",
                "Everything good is right where you left it."
            ]
        default:
            messages = [
                "One more before calling it a night?",
                "Your late-night watch is ready.",
                "Everything good is still right where you left it."
            ]
        }
        return messages[day % messages.count]
    }

    private func liveShelf(_ channels: [LiveChannel]) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Live on Tater Tube")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 28) {
                    ForEach(channels) { channel in
                        TaterCardButton(cornerRadius: 22) {
                            Task { await store.play(channel) }
                        } label: {
                            LiveChannelCardView(channel: channel, guide: store.liveGuide)
                        }
                    }

                    TaterCardButton(cornerRadius: 22, action: { selectedTab = 2 }) {
                        ShelfDestinationCard(title: "Open Guide", icon: "list.bullet.rectangle.fill")
                    }
                }
                .padding(.horizontal, 34)
                .padding(.vertical, 24)
            }
            .scrollClipDisabled()
            .contentMargins(.horizontal, -34, for: .scrollContent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .focusSection()
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
    let handlesRecentlyAddedShows: Bool
    let onNavigate: (LibraryLocation) -> Void

    init(
        title: String,
        items: [MediaItem],
        destination: LibraryLocation? = nil,
        handlesRecentlyAddedShows: Bool = false,
        onNavigate: @escaping (LibraryLocation) -> Void = { _ in }
    ) {
        self.title = title
        self.items = items
        self.destination = destination
        self.handlesRecentlyAddedShows = handlesRecentlyAddedShows
        self.onNavigate = onNavigate
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(title)
                .font(.system(size: 34, weight: .bold, design: .rounded))

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 28) {
                    ForEach(items) { item in
                        TaterCardButton(cornerRadius: 22) {
                            open(item)
                        } label: { WideMediaCardView(item: item) }
                    }

                    if let destination {
                        TaterCardButton(cornerRadius: 22, action: { onNavigate(destination) }) {
                            ShelfDestinationCard(title: "See All", icon: "arrow.right.circle.fill")
                        }
                    }
                }
                .padding(.horizontal, 34)
                .padding(.vertical, 24)
            }
            .scrollClipDisabled()
            .contentMargins(.horizontal, -34, for: .scrollContent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .focusSection()
    }

    private func open(_ item: MediaItem) {
        let kind = item.mediaType?.lowercased() ?? ""
        guard handlesRecentlyAddedShows,
              ["show", "series", "tv", "tvshow"].contains(kind)
        else {
            store.openDetails(for: item)
            return
        }

        if item.recentItems.count == 1, let episode = item.recentItems.first {
            store.openDetails(for: episode)
            return
        }
        if let firstEpisode = item.recentItems.first,
           let location = LibraryLocation.recentlyAddedBatch(
               for: item,
               firstEpisode: firstEpisode
           ) {
            onNavigate(location)
            return
        }

        // Older servers do not include the import batch. Open the series instead
        // of presenting a non-playable show as though it were an episode.
        let parent = destination ?? LibraryLocation(
            categoryID: item.categoryID ?? "",
            title: "Recently Added"
        )
        onNavigate(LibraryLocation(item: item, parent: parent))
    }
}

struct ShelfDestinationCard: View {
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
        .frame(width: 190, height: 202)
        .taterGlass(cornerRadius: 24)
    }
}
