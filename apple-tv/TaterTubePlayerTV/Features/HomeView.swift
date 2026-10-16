import Combine
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: PlayerStore
    @Binding var selectedTab: Int
    let onReturnToTopNavigation: () -> Void
    let contentFocusRequest: Int
    @State private var navigationPath: [LibraryLocation] = []
    @State private var focusedHeroItem: MediaItem?
    @State private var focusedShelfID: String?
    @State private var requestedFocusShelfID: String?
    @State private var shelfFocusRequest = 0
    @State private var heroClock = Date()

    private let heroClockTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .topLeading) {
                CinematicHomeBackdrop(item: displayedHeroItem)

                VStack(alignment: .leading, spacing: 0) {
                    homeHero
                        .padding(.horizontal, 70)

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 42) {
                            if let items = store.home?.continueWatching, !items.isEmpty {
                                let shelfID = HomeShelfID.continueWatching
                                MediaShelf(
                                    title: "CONTINUE WATCHING",
                                    items: items,
                                    destination: continueWatchingLocation,
                                    focusRequest: requestedFocusShelfID == shelfID ? shelfFocusRequest : nil,
                                    onFocus: { focus($0, in: shelfID) },
                                    onDestinationFocus: { focusedShelfID = shelfID },
                                    onNavigate: { navigationPath.append($0) }
                                )
                                .id(shelfID)
                            }

                            if let items = store.home?.recentlyAdded, !items.isEmpty {
                                let shelfID = HomeShelfID.recentlyAdded
                                MediaShelf(
                                    title: "RECENTLY ADDED",
                                    items: items,
                                    destination: recentlyAddedLocation,
                                    handlesRecentlyAddedShows: true,
                                    focusRequest: requestedFocusShelfID == shelfID ? shelfFocusRequest : nil,
                                    onFocus: { focus($0, in: shelfID) },
                                    onDestinationFocus: { focusedShelfID = shelfID },
                                    onNavigate: { navigationPath.append($0) }
                                )
                                .id(shelfID)
                            }

                            ForEach(homeBrowseRows) { row in
                                let shelfID = homeShelfID(for: row)
                                MediaShelf(
                                    title: row.title.uppercased(),
                                    items: row.items,
                                    destination: LibraryLocation(entry: row.entry),
                                    focusRequest: requestedFocusShelfID == shelfID ? shelfFocusRequest : nil,
                                    onFocus: { focus($0, in: shelfID) },
                                    onDestinationFocus: { focusedShelfID = shelfID },
                                    onNavigate: { navigationPath.append($0) }
                                )
                                .id(shelfID)
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.horizontal, 70)
                        .padding(.top, 18)
                        .padding(.bottom, 360)
                    }
                    .refreshable {
                        await store.refreshHome()
                        await store.refreshLibraryRows(showActivity: false)
                    }
                    .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
                }
            }
            .navigationDestination(for: LibraryLocation.self) { location in
                LibraryCollectionView(
                    location: location,
                    onNavigate: { navigationPath.append($0) }
                )
            }
        }
        .onExitCommand {
            if navigationPath.isEmpty {
                onReturnToTopNavigation()
            } else {
                navigationPath.removeLast()
            }
        }
        .onAppear {
            heroClock = Date()
            seedHeroIfNeeded()
            Task {
                await store.refreshHome(minimumInterval: 10, reportErrors: false)
                await store.refreshLibraryRows(
                    showActivity: false,
                    minimumInterval: 10,
                    reportErrors: false
                )
                seedHeroIfNeeded()
            }
        }
        .onReceive(heroClockTimer) { date in
            heroClock = date
            Task {
                await store.refreshHome(minimumInterval: 55, reportErrors: false)
                await store.refreshLibraryRows(
                    showActivity: false,
                    minimumInterval: 55,
                    reportErrors: false
                )
            }
        }
        .onChange(of: contentFocusRequest) { _, _ in
            requestEntryFocusIfNeeded()
        }
    }

    private var displayedHeroItem: MediaItem? {
        focusedHeroItem
            ?? store.home?.continueWatching.first
            ?? store.home?.recentlyAdded.first
            ?? homeBrowseRows.first?.items.first
    }

    private var homeHero: some View {
        VStack(alignment: .leading, spacing: 17) {
            if let item = displayedHeroItem {
                Text(item.title)
                    .font(.system(size: 62, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                if let metadata = heroMetadata(for: item) {
                    Text(metadata)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                }

                if let summary = item.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.system(size: 24, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(3)
                        .frame(maxWidth: 760, alignment: .leading)
                } else if item.visibleProgress <= 0,
                          let subtitle = item.subtitle,
                          !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 24, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(2)
                }

                if item.visibleProgress > 0 {
                    HStack(spacing: 16) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.22))
                                Capsule()
                                    .fill(TaterTheme.orange)
                                    .frame(width: geometry.size.width * item.visibleProgress)
                            }
                        }
                        .frame(width: 390, height: 7)

                        Text(progressLabel(for: item))
                            .font(.system(size: 19, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                }

                HStack(spacing: 12) {
                    ForEach(heroChips(for: item), id: \.self) { value in
                        Text(value)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.90))
                            .padding(.horizontal, 13)
                            .padding(.vertical, 7)
                            .background(Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 6))
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.32), lineWidth: 1.5)
                            }
                    }
                }
            } else {
                Text(heroEyebrow)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .tracking(2.4)
                    .foregroundStyle(TaterTheme.orangeBright)

                Text(heroMessage)
                    .font(.system(size: 58, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .frame(maxWidth: 780, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 405, alignment: .leading)
        .padding(.top, 46)
    }

    private func selectHero(_ item: MediaItem) {
        var transaction = Transaction()
        transaction.animation = nil
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            focusedHeroItem = item
        }
    }

    private func focus(_ item: MediaItem, in shelfID: String) {
        focusedShelfID = shelfID
        selectHero(item)
    }

    private func seedHeroIfNeeded() {
        guard focusedHeroItem == nil else { return }
        focusedHeroItem = store.home?.continueWatching.first
            ?? store.home?.recentlyAdded.first
            ?? homeBrowseRows.first?.items.first
    }

    private func requestEntryFocusIfNeeded() {
        guard let shelfID = focusedShelfID ?? firstVisibleShelfID else { return }
        requestedFocusShelfID = shelfID
        shelfFocusRequest &+= 1
    }

    private func heroMetadata(for item: MediaItem) -> String? {
        [item.date]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: "  •  ")
            .nilIfEmpty
    }

    private func heroChips(for item: MediaItem) -> [String] {
        item.cinematicMetadataChips
    }

    private func progressLabel(for item: MediaItem) -> String {
        if let subtitle = item.subtitle, !subtitle.isEmpty { return subtitle }
        if let duration = item.durationDisplay, !duration.isEmpty { return duration }
        let percent = Int((item.progressPercent ?? Double(item.visibleProgress * 100)).rounded())
        return "\(percent)% watched"
    }

    private var heroEyebrow: String {
        let calendar = Calendar.current
        let weekday = heroClock.formatted(.dateTime.weekday(.wide)).uppercased()
        let hour = calendar.component(.hour, from: heroClock)
        let timeOfDay: String
        switch hour {
        case 5..<12: timeOfDay = "MORNING"
        case 12..<17: timeOfDay = "AFTERNOON"
        case 17..<22: timeOfDay = "EVENING"
        default: timeOfDay = "LATE NIGHT"
        }
        return "\(weekday) \(timeOfDay)"
    }

    private var heroMessage: String {
        let hour = Calendar.current.component(.hour, from: heroClock)
        switch hour {
        case 5..<12: return "Start the day with something good."
        case 12..<17: return "Your afternoon watch is ready."
        case 17..<22: return "Your next watch starts here."
        default: return "Everything good is right where you left it."
        }
    }

    private var continueWatchingLocation: LibraryLocation {
        if let row = store.libraryRows.first(where: { $0.entry.type?.lowercased() == "continue" }) {
            return LibraryLocation(entry: row.entry)
        }
        return LibraryLocation(categoryID: "", title: "Continue Watching", continueWatching: true)
    }

    private var recentlyAddedLocation: LibraryLocation {
        if let row = store.libraryRows.first(where: { $0.entry.id.lowercased() == "local-discover:recent" }) {
            return LibraryLocation(entry: row.entry)
        }
        return LibraryLocation(categoryID: "local-discover:recent", title: "Recently Added")
    }

    private var homeBrowseRows: [LibraryRow] {
        store.libraryRows.filter { row in
            let id = row.entry.id.lowercased()
            let type = row.entry.type?.lowercased() ?? ""
            return !row.items.isEmpty
                && id != "local-discover:movies"
                && id != "local-discover:series"
                && id != "local-discover:recent"
                && type != "continue"
                && type != "local"
        }
    }

    private var firstVisibleShelfID: String? {
        if store.home?.continueWatching.isEmpty == false {
            return HomeShelfID.continueWatching
        }
        if store.home?.recentlyAdded.isEmpty == false {
            return HomeShelfID.recentlyAdded
        }
        return homeBrowseRows.first.map(homeShelfID(for:))
    }

    private func homeShelfID(for row: LibraryRow) -> String {
        "home-library-\(row.id)"
    }

}

private enum HomeShelfID {
    static let continueWatching = "home-shelf-continue"
    static let recentlyAdded = "home-shelf-recent"
}

private struct CinematicHomeBackdrop: View {
    let item: MediaItem?

    var body: some View {
        ZStack(alignment: .top) {
            TaterTheme.background

            if let item {
                ArtworkView(
                    remoteValue: item.wideShelfArtwork,
                    demoName: item.wideDemoArtworkName,
                    showsPlaceholder: false
                )
                .frame(maxWidth: .infinity)
                .frame(height: 720, alignment: .top)
                .clipped()
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .white, location: 0),
                            .init(color: .white, location: 0.70),
                            .init(color: .white.opacity(0.72), location: 0.84),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }

            LinearGradient(
                colors: [Color.black.opacity(0.96), Color.black.opacity(0.55), Color.black.opacity(0.05)],
                startPoint: .leading,
                endPoint: .trailing
            )
            LinearGradient(
                colors: [Color.black.opacity(0.04), Color.black.opacity(0.18), Color.black.opacity(0.96), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

struct MediaShelf: View {
    @EnvironmentObject private var store: PlayerStore
    @State private var selectedIndex = 0
    @State private var selectionHasFocus = false
    @FocusState private var selectionFocus: Bool

    let title: String
    let items: [MediaItem]
    let destination: LibraryLocation?
    let handlesRecentlyAddedShows: Bool
    let focusRequest: Int?
    let onFocus: (MediaItem) -> Void
    let onDestinationFocus: () -> Void
    let onNavigate: (LibraryLocation) -> Void

    init(
        title: String,
        items: [MediaItem],
        destination: LibraryLocation? = nil,
        handlesRecentlyAddedShows: Bool = false,
        focusRequest: Int? = nil,
        onFocus: @escaping (MediaItem) -> Void = { _ in },
        onDestinationFocus: @escaping () -> Void = {},
        onNavigate: @escaping (LibraryLocation) -> Void = { _ in }
    ) {
        self.title = title
        self.items = items
        self.destination = destination
        self.handlesRecentlyAddedShows = handlesRecentlyAddedShows
        self.focusRequest = focusRequest
        self.onFocus = onFocus
        self.onDestinationFocus = onDestinationFocus
        self.onNavigate = onNavigate
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(.system(size: 29, weight: .bold, design: .rounded))
                .tracking(3)

            GeometryReader { shelfGeometry in
                ScrollViewReader { scrollProxy in
                    ZStack(alignment: .topLeading) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(alignment: .top, spacing: 25) {
                                ForEach(items) { item in
                                    WideMediaCardView(item: item, width: 345)
                                        .id(scrollID(for: item))
                                }

                                if destination != nil {
                                    ShelfDestinationCard(
                                        title: "See All",
                                        icon: "arrow.right.circle.fill",
                                        width: 345
                                    )
                                    .id(destinationScrollID)
                                }

                                // Leave enough content after the final card for
                                // it to align beneath the fixed leading focus
                                // frame instead of clamping at the trailing edge.
                                Color.clear
                                    .frame(
                                        width: max(0, shelfGeometry.size.width - 345 - 25),
                                        height: 202
                                    )
                                    .accessibilityHidden(true)
                            }
                            .padding(.vertical, 22)
                        }
                        .scrollClipDisabled()
                        .allowsHitTesting(false)

                        TaterCardButton(
                            cornerRadius: 18,
                            action: activateSelection,
                            onFocusChange: { focused in
                                selectionHasFocus = focused
                                if focused { announceSelection() }
                            },
                            requestedFocus: $selectionFocus
                        ) {
                            Color.clear
                                .frame(width: 345, height: 202)
                        }
                        .padding(.vertical, 22)
                        .onMoveCommand { direction in
                            switch direction {
                            case .left:
                                moveSelection(by: -1, using: scrollProxy)
                            case .right:
                                moveSelection(by: 1, using: scrollProxy)
                            default:
                                break
                            }
                        }
                        .onKeyPress(
                            keys: [.leftArrow, .rightArrow],
                            phases: .repeat
                        ) { press in
                            switch press.key {
                            case .leftArrow:
                                moveSelection(by: -1, using: scrollProxy, duration: 0.12)
                            case .rightArrow:
                                moveSelection(by: 1, using: scrollProxy, duration: 0.12)
                            default:
                                return .ignored
                            }
                            return .handled
                        }
                        .accessibilityLabel(selectionAccessibilityLabel)
                        .accessibilityHint("Press left or right to browse this row")
                    }
                }
            }
            .frame(height: 246)
            .onChange(of: items.map(\.id)) { _, _ in
                selectedIndex = min(selectedIndex, max(0, selectionCount - 1))
                if selectionHasFocus { announceSelection() }
            }
            .onChange(of: focusRequest) { _, request in
                guard request != nil else { return }
                Task { @MainActor in
                    await Task.yield()
                    selectionFocus = true
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .focusSection()
    }

    private var selectionCount: Int {
        items.count + (destination == nil ? 0 : 1)
    }

    private var selectedItem: MediaItem? {
        guard items.indices.contains(selectedIndex) else { return nil }
        return items[selectedIndex]
    }

    private var destinationIsSelected: Bool {
        destination != nil && selectedIndex == items.count
    }

    private var destinationScrollID: String {
        "home-shelf-destination-\(title)"
    }

    private var selectionAccessibilityLabel: String {
        if destinationIsSelected { return "See all \(title)" }
        return selectedItem?.title ?? title
    }

    private func scrollID(for item: MediaItem) -> String {
        "home-shelf-item-\(item.id)"
    }

    private func moveSelection(
        by offset: Int,
        using scrollProxy: ScrollViewProxy,
        duration: Double = 0.24
    ) {
        let nextIndex = min(max(selectedIndex + offset, 0), max(0, selectionCount - 1))
        guard nextIndex != selectedIndex else { return }
        selectedIndex = nextIndex
        announceSelection()
        withAnimation(.easeOut(duration: duration)) {
            if destinationIsSelected {
                scrollProxy.scrollTo(destinationScrollID, anchor: .leading)
            } else if let selectedItem {
                scrollProxy.scrollTo(scrollID(for: selectedItem), anchor: .leading)
            }
        }
    }

    private func announceSelection() {
        if let selectedItem {
            onFocus(selectedItem)
        } else if destinationIsSelected {
            onDestinationFocus()
        }
    }

    private func activateSelection() {
        if let selectedItem {
            open(selectedItem)
        } else if destinationIsSelected, let destination {
            onNavigate(destination)
        }
    }

    private func open(_ item: MediaItem) {
        let kind = item.mediaType?.lowercased() ?? ""
        guard handlesRecentlyAddedShows, ["show", "series", "tv", "tvshow"].contains(kind) else {
            if item.isBrowsableLibraryItem, let destination {
                onNavigate(LibraryLocation(item: item, parent: destination))
            } else {
                store.openDetails(for: item)
            }
            return
        }

        if item.recentItems.count == 1, let episode = item.recentItems.first {
            store.openDetails(for: episode)
            return
        }
        if let firstEpisode = item.recentItems.first,
           let location = LibraryLocation.recentlyAddedBatch(for: item, firstEpisode: firstEpisode) {
            onNavigate(location)
            return
        }
        let parent = destination ?? LibraryLocation(categoryID: item.categoryID ?? "", title: "Recently Added")
        onNavigate(LibraryLocation(item: item, parent: parent))
    }
}

struct ShelfDestinationCard: View {
    let title: String
    let icon: String
    var width: CGFloat = 190

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 58, weight: .medium))
            Text(title)
                .font(.system(size: 23, weight: .bold, design: .rounded))
        }
        .foregroundStyle(.white)
        .frame(width: width, height: 202)
        .taterGlass(cornerRadius: 24)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
