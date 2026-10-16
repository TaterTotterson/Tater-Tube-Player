import SwiftUI

struct TopLevelLibraryView: View {
    @Binding var selectedTab: Int
    let onReturnToTopNavigation: () -> Void
    let contentFocusRequest: Int
    @State private var navigationPath: [LibraryLocation] = []

    let location: LibraryLocation

    init(
        location: LibraryLocation,
        selectedTab: Binding<Int>,
        onReturnToTopNavigation: @escaping () -> Void,
        contentFocusRequest: Int = 0
    ) {
        self.location = location
        _selectedTab = selectedTab
        self.onReturnToTopNavigation = onReturnToTopNavigation
        self.contentFocusRequest = contentFocusRequest
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            LibraryCollectionView(
                location: location,
                contentFocusRequest: contentFocusRequest,
                onNavigate: { navigationPath.append($0) }
            )
            .navigationDestination(for: LibraryLocation.self) { destination in
                LibraryCollectionView(
                    location: destination,
                    contentFocusRequest: contentFocusRequest,
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
    }
}

struct LibraryView: View {
    @EnvironmentObject private var store: PlayerStore
    @Binding var selectedTab: Int
    @State private var navigationPath: [LibraryLocation] = []
    @State private var topFocusRequest = 0

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                LibraryGlowBackground()

                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 54) {
                            collectionBar

                            ForEach(displayRows) { row in
                                LibraryShelf(
                                    row: row,
                                    onNavigate: { navigationPath.append($0) }
                                )
                            }

                            if displayRows.isEmpty && !store.isLibraryRefreshing {
                                LibraryEmptyState(
                                    title: "Your library is ready for a scan",
                                    message: "Movies, shows, and collections from your Tater Tube Server will appear here."
                                )
                            }
                        }
                        .padding(.horizontal, 78)
                        .padding(.top, 42)
                        .padding(.bottom, 110)
                        .id("library-scroll-top")
                    }
                    .refreshable { await store.refreshLibraryRows() }
                    .onExitCommand { selectedTab = 0 }
                    .onChange(of: topFocusRequest) { _, _ in
                        withAnimation(.easeOut(duration: 0.20)) {
                            scrollProxy.scrollTo("library-scroll-top", anchor: .top)
                        }
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
        .task {
            await store.refreshLibraryRows(
                showActivity: store.libraryRows.isEmpty,
                minimumInterval: 10
            )
        }
    }

    private var collectionBar: some View {
        HStack(spacing: 24) {
            TaterActionButton(
                action: { navigationPath.append(.allMovies) },
                onFocusChange: restoreTopWhenFocused
            ) {
                Label("All Movies", systemImage: "film.fill")
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 72)
            }

            TaterActionButton(
                action: { navigationPath.append(.allShows) },
                onFocusChange: restoreTopWhenFocused
            ) {
                Label("All TV Shows", systemImage: "tv.and.mediabox.fill")
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 72)
            }

            if store.home?.capabilities.newznab == true {
                TaterActionButton(
                    action: { selectedTab = 3 },
                    onFocusChange: restoreTopWhenFocused
                ) {
                    Label("Discover", systemImage: "sparkles.tv.fill")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 72)
                }
            }

            if store.home?.capabilities.taterLink == true {
                TaterActionButton(
                    action: { selectedTab = 4 },
                    onFocusChange: restoreTopWhenFocused
                ) {
                    Label("Tater Picks", systemImage: "wand.and.stars")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 72)
                }
            }
        }
        .padding(30)
        .taterGlass(cornerRadius: 30)
        .focusSection()
    }

    private func restoreTopWhenFocused(_ focused: Bool) {
        if focused { topFocusRequest += 1 }
    }

    private var displayRows: [LibraryRow] {
        store.libraryRows.filter { row in
            let id = row.entry.id.lowercased()
            let type = row.entry.type?.lowercased() ?? ""
            return !row.items.isEmpty
                && id != "local-discover:movies"
                && id != "local-discover:series"
                && type != "local"
        }
    }
}

private struct LibraryShelf: View {
    let row: LibraryRow
    let onNavigate: (LibraryLocation) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(row.title)
                .font(.system(size: 34, weight: .bold, design: .rounded))

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 28) {
                    ForEach(row.items) { item in
                        LibraryItemLink(
                            item: item,
                            parent: LibraryLocation(entry: row.entry),
                            wide: true,
                            handlesRecentlyAddedShows: row.entry.id.lowercased() == "local-discover:recent",
                            onNavigate: onNavigate
                        )
                    }

                    TaterCardButton(cornerRadius: 22, action: {
                        onNavigate(LibraryLocation(entry: row.entry))
                    }) {
                        ShelfDestinationCard(title: "See All", icon: "arrow.right.circle.fill")
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
}

struct LibraryCollectionView: View {
    @EnvironmentObject private var store: PlayerStore
    @State private var heroFocusRequest = 0
    @FocusState private var focusedItemID: String?

    let location: LibraryLocation
    var contentFocusRequest = 0
    let onNavigate: (LibraryLocation) -> Void

    private var page: LibraryPage? { store.libraryPage(for: location) }
    private var items: [MediaItem] { page?.items.naturallySorted ?? [] }
    private var stage: LibraryStage { LibraryStage(location: location, items: items) }

    var body: some View {
        ZStack {
            collectionBackground

            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 44) {
                        if stage == .seasons {
                            SeriesDetailContent(
                                location: location,
                                seasons: items,
                                contentFocusRequest: contentFocusRequest,
                                onPrepareSeasonNavigation: {
                                    var transaction = Transaction()
                                    transaction.disablesAnimations = true
                                    withTransaction(transaction) {
                                        scrollProxy.scrollTo("library-collection-top", anchor: .top)
                                    }
                                }
                            )
                        } else if stage.showsHero {
                            LibraryContextHero(
                                location: location,
                                items: items,
                                onFocusChange: restoreHeroWhenFocused
                            )
                        }

                        if stage == .seasons {
                            EmptyView()
                        } else if let page, page.items.isEmpty {
                            LibraryEmptyState(
                                title: "Nothing here yet",
                                message: "This collection is currently empty on your Tater Tube Server."
                            )
                        } else if stage == .episodes {
                            episodeGrid
                        } else {
                            posterGrid
                        }

                        if page == nil && store.loadingLibraryPages.contains(location.cacheKey) {
                            HStack(spacing: 18) {
                                ProgressView()
                                    .tint(TaterTheme.orange)
                                Text("Loading \(location.title)…")
                                    .font(.system(size: 25, weight: .semibold, design: .rounded))
                                    .foregroundStyle(TaterTheme.secondaryText)
                            }
                            .frame(maxWidth: .infinity, minHeight: 260)
                        }

                        if let error = store.libraryErrors[location.cacheKey], page == nil {
                            LibraryEmptyState(title: "Couldn’t load this collection", message: error)
                        }
                    }
                    .padding(.horizontal, 78)
                    .padding(.top, stage.showsHero ? 28 : 52)
                    .padding(.bottom, 120)
                    .id("library-collection-top")
                }
                .refreshable { await store.loadLibraryPage(location, forceNetwork: true) }
                .onChange(of: heroFocusRequest) { _, _ in
                    withAnimation(.easeOut(duration: 0.20)) {
                        scrollProxy.scrollTo("library-collection-top", anchor: .top)
                    }
                }
            }
        }
        .navigationTitle("")
        .task(id: location.cacheKey) {
            await store.loadLibraryPage(location)
            if let initialFocusItemID = location.initialFocusItemID {
                await Task.yield()
                focusedItemID = initialFocusItemID
            }
        }
    }

    @ViewBuilder
    private var collectionBackground: some View {
        if stage.showsHero,
           location.backdrop != nil || location.poster != nil || location.demoArtworkName != nil {
            ZStack {
                ArtworkView(
                    remoteValue: location.backdrop ?? location.poster,
                    demoName: location.demoArtworkName
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()

                LinearGradient(
                    colors: [Color.black.opacity(0.94), Color.black.opacity(0.45), Color.black.opacity(0.10)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .ignoresSafeArea()
                LinearGradient(
                    colors: [Color.black.opacity(0.12), Color.black.opacity(0.60), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
        } else {
            LibraryGlowBackground()
        }
    }

    private var posterGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 238, maximum: 258), spacing: 34)],
            alignment: .leading,
            spacing: 38
        ) {
            ForEach(items) { item in
                LibraryItemLink(
                    item: item,
                    parent: location,
                    onNavigate: onNavigate
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .focusSection()
    }

    private var episodeGrid: some View {
        LazyVStack(alignment: .leading, spacing: 22) {
            ForEach(items) { item in
                TaterCardButton(cornerRadius: 20) {
                    store.openDetails(for: item)
                } label: {
                    CinematicEpisodeRow(item: item)
                }
                .focused($focusedItemID, equals: item.id)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .focusSection()
    }

    private func restoreHeroWhenFocused(_ focused: Bool) {
        if focused { heroFocusRequest += 1 }
    }
}

private struct LibraryItemLink: View {
    @EnvironmentObject private var store: PlayerStore

    let item: MediaItem
    let parent: LibraryLocation
    var wide = false
    var handlesRecentlyAddedShows = false
    let onNavigate: (LibraryLocation) -> Void

    var body: some View {
        if item.isBrowsableLibraryItem {
            TaterCardButton(
                cornerRadius: wide ? 22 : 20,
                usesDarkFocusSurface: !wide,
                action: {
                    openBrowsableItem()
                }
            ) {
                if wide {
                    WideMediaCardView(item: item)
                } else if item.mediaType?.lowercased() == "season" {
                    SeasonCardView(item: item)
                } else {
                    MediaCardView(item: item)
                }
            }
        } else {
            TaterCardButton(cornerRadius: 20, usesDarkFocusSurface: !wide) {
                store.openDetails(for: item)
            } label: {
                if wide {
                    WideMediaCardView(item: item)
                } else {
                    MediaCardView(item: item)
                }
            }
        }
    }

    private func openBrowsableItem() {
        if handlesRecentlyAddedShows,
           item.recentItems.count == 1,
           let episode = item.recentItems.first {
            store.openDetails(for: episode)
            return
        }
        if handlesRecentlyAddedShows,
           let firstEpisode = item.recentItems.first,
           let location = LibraryLocation.recentlyAddedBatch(
               for: item,
               firstEpisode: firstEpisode
           ) {
            onNavigate(location)
            return
        }
        onNavigate(LibraryLocation(item: item, parent: parent))
    }
}

private struct SeriesDetailContent: View {
    @EnvironmentObject private var store: PlayerStore
    @State private var selectedSeasonID: String?
    @State private var isSeasonNavigationActive = false
    @State private var isEpisodeNavigationActive = false
    @State private var isEnteringEpisodes = false
    @State private var isEnteringSeason = false
    @State private var requestedSeasonFocusID: String?
    @State private var episodeToRestoreID: String?
    @FocusState private var focusedSeasonID: String?
    @FocusState private var focusedEpisodeID: String?
    @FocusState private var episodeFocusLandingHasFocus: Bool

    let location: LibraryLocation
    let seasons: [MediaItem]
    let contentFocusRequest: Int
    let onPrepareSeasonNavigation: () -> Void

    private var selectedSeason: MediaItem? {
        seasons.first(where: { $0.id == selectedSeasonID }) ?? seasons.first
    }

    private var selectedSeasonLocation: LibraryLocation? {
        selectedSeason.map { LibraryLocation(item: $0, parent: location) }
    }

    private var episodes: [MediaItem] {
        guard let selectedSeasonLocation else { return [] }
        return store.libraryPage(for: selectedSeasonLocation)?.items.naturallySorted ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            seriesHero

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 28) {
                    ForEach(seasons) { season in
                        SeasonSelectorButton(
                            id: season.id,
                            title: season.title.uppercased(),
                            selected: season.id == selectedSeason?.id,
                            visuallyFocused: isSeasonNavigationActive
                                && season.id == (requestedSeasonFocusID ?? focusedSeasonID),
                            focusedSeasonID: $focusedSeasonID,
                            action: { selectedSeasonID = season.id }
                        )
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
            .scrollClipDisabled()
            .contentMargins(.horizontal, -18, for: .scrollContent)
            .focusSection()
            .disabled(isEpisodeNavigationActive)

            if let selectedSeasonLocation,
               store.loadingLibraryPages.contains(selectedSeasonLocation.cacheKey),
               episodes.isEmpty {
                HStack(spacing: 16) {
                    ProgressView().tint(TaterTheme.orange)
                    Text("Loading \(selectedSeasonLocation.title)…")
                        .font(.system(size: 23, weight: .semibold, design: .rounded))
                        .foregroundStyle(TaterTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, minHeight: 220)
            } else if episodes.isEmpty {
                LibraryEmptyState(
                    title: "No episodes found",
                    message: "This season does not have any episodes available yet."
                )
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    EpisodeFocusLanding(
                        isEnabled: !isEnteringSeason
                            && (isSeasonNavigationActive
                                || isEpisodeNavigationActive
                                || isEnteringEpisodes),
                        hasFocus: $episodeFocusLandingHasFocus,
                        onFocus: handleEpisodeBoundaryFocus
                    )

                    LazyVStack(alignment: .leading, spacing: 22) {
                        ForEach(episodes) { episode in
                            TaterCardButton(cornerRadius: 20) {
                                episodeToRestoreID = episode.id
                                store.openDetails(for: episode)
                            } label: {
                                CinematicEpisodeRow(item: episode)
                            }
                            .focused($focusedEpisodeID, equals: episode.id)
                        }
                    }
                    .disabled(isSeasonNavigationActive)
                }
                .focusSection()
            }
        }
        .task(id: seasons.map(\.id)) {
            if selectedSeasonID == nil || !seasons.contains(where: { $0.id == selectedSeasonID }) {
                selectedSeasonID = preferredSeasonID
            }
        }
        .task(id: selectedSeasonID) {
            guard let selectedSeasonLocation else { return }
            await store.loadLibraryPage(selectedSeasonLocation)
        }
        .onChange(of: focusedSeasonID) { previous, current in
            guard let current else { return }
            isSeasonNavigationActive = true
            isEpisodeNavigationActive = false

            if let requestedSeasonFocusID {
                guard current == requestedSeasonFocusID else {
                    DispatchQueue.main.async {
                        guard self.requestedSeasonFocusID == requestedSeasonFocusID else { return }
                        withoutFocusAnimation {
                            focusedSeasonID = requestedSeasonFocusID
                        }
                    }
                    return
                }

                self.requestedSeasonFocusID = nil
                return
            }

            if current != selectedSeasonID {
                selectedSeasonID = current
            }
        }
        .onChange(of: focusedEpisodeID) { _, current in
            guard current != nil else { return }

            // Clearing a focused episode while returning to the season strip
            // can make tvOS briefly propose episode one as a replacement.
            // Do not let that transient focus cancel the season handoff.
            if isEnteringSeason {
                withoutFocusAnimation {
                    focusedEpisodeID = nil
                }
                return
            }

            isEpisodeNavigationActive = true
            isSeasonNavigationActive = false
        }
        .onChange(of: contentFocusRequest) { _, _ in
            restoreEpisodeFocusAfterDetails()
        }
        .modifier(
            SeasonNavigationBackModifier(
                enabled: store.selectedMedia == nil
                    && !isSeasonNavigationActive
                    && focusedSeasonID == nil
                    && selectedSeason != nil,
                action: enterSeasonNavigation
            )
        )
    }

    private func enterSeasonNavigation() {
        guard !isEnteringSeason, let seasonID = selectedSeason?.id else { return }
        isEnteringSeason = true
        episodeFocusLandingHasFocus = false
        requestedSeasonFocusID = seasonID
        isSeasonNavigationActive = true
        isEpisodeNavigationActive = false
        focusedEpisodeID = nil
        onPrepareSeasonNavigation()

        // The selector may be several screens above the focused episode. Wait
        // for the nonanimated scroll to lay it out before transferring focus.
        DispatchQueue.main.async {
            withoutFocusAnimation {
                focusedSeasonID = seasonID
            }

            DispatchQueue.main.async {
                withoutFocusAnimation {
                    focusedSeasonID = seasonID
                }
                isEnteringSeason = false
            }
        }
    }

    private func enterEpisodeNavigation() {
        guard isSeasonNavigationActive, !isEnteringEpisodes else { return }
        guard let firstEpisodeID = episodes.first?.id else { return }

        // Keep the landing target focused while the episode rows re-enter the
        // focus system. This prevents tvOS from briefly choosing a lower row by
        // geometry before we transfer directly to episode one.
        isEnteringEpisodes = true
        withoutFocusAnimation {
            requestedSeasonFocusID = nil
            isSeasonNavigationActive = false
            focusedSeasonID = nil
        }

        Task { @MainActor in
            await Task.yield()
            guard episodes.contains(where: { $0.id == firstEpisodeID }) else {
                isEnteringEpisodes = false
                return
            }
            withoutFocusAnimation {
                focusedEpisodeID = firstEpisodeID
            }
            await Task.yield()
            isEnteringEpisodes = false
        }
    }

    private func handleEpisodeBoundaryFocus() {
        if isEpisodeNavigationActive {
            enterSeasonNavigation()
        } else {
            enterEpisodeNavigation()
        }
    }

    private func restoreEpisodeFocusAfterDetails() {
        guard let episodeID = episodeToRestoreID,
              episodes.contains(where: { $0.id == episodeID }) else { return }

        // This is a one-time handoff from the dismissed detail popup. Leaving
        // it armed lets a later content-focus request pull focus back to this
        // stale episode while the user is moving into the season selector.
        episodeToRestoreID = nil

        isEnteringEpisodes = false
        requestedSeasonFocusID = nil
        isSeasonNavigationActive = false
        isEpisodeNavigationActive = true
        focusedSeasonID = nil

        Task { @MainActor in
            // The popup has already left the focus tree when this request is
            // delivered. Yield once so the episode row is focusable again,
            // then restore the exact row that opened it.
            await Task.yield()
            withoutFocusAnimation {
                focusedEpisodeID = episodeID
            }
        }
    }

    private func withoutFocusAnimation(_ updates: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, updates)
    }

    private var seriesHero: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(location.title)
                .font(.system(size: 58, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)

            Text(seriesMetadata)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.80))

            if let summary = location.summary, !summary.isEmpty {
                Text(summary)
                    .font(.system(size: 24, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.80))
                    .lineLimit(3)
                    .frame(maxWidth: 820, alignment: .leading)
            }

            if let upNextLabel {
                Text("Up next: \(upNextLabel)")
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                    .foregroundStyle(TaterTheme.orangeBright)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 255, alignment: .bottomLeading)
    }

    private var seriesMetadata: String {
        let episodeCount = seasons.reduce(0) { $0 + max($1.episodeCount, $1.leafCount) }
        return "\(seasons.count) \(seasons.count == 1 ? "Season" : "Seasons")"
            + (episodeCount > 0 ? "  •  \(episodeCount) Episodes" : "")
    }

    private var upNextLabel: String? {
        seasons.compactMap(\.resumeTitle).first(where: { !$0.isEmpty })
    }

    private var preferredSeasonID: String? {
        if let resumable = seasons.first(where: { $0.resumeTitle?.isEmpty == false }) {
            return resumable.id
        }
        return seasons.first?.id
    }
}

private struct EpisodeFocusLanding: View {
    let isEnabled: Bool
    let hasFocus: FocusState<Bool>.Binding
    let onFocus: () -> Void

    var body: some View {
        Color.white.opacity(0.001)
            .frame(maxWidth: .infinity)
            .frame(height: 12)
            .contentShape(Rectangle())
            .focusable(isEnabled)
            .focused(hasFocus)
            .focusEffectDisabled()
            .onChange(of: hasFocus.wrappedValue) { _, focused in
                if focused { onFocus() }
            }
            .accessibilityHidden(true)
    }
}

private struct SeasonSelectorButton: View {
    let id: String
    let title: String
    let selected: Bool
    let visuallyFocused: Bool
    let focusedSeasonID: FocusState<String?>.Binding
    let action: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .tracking(2.6)
                .foregroundStyle(
                    visuallyFocused
                        ? TaterTheme.orangeBright
                        : (selected ? Color.white : Color.white.opacity(0.72))
                )

            Capsule()
                .fill(selected || visuallyFocused ? TaterTheme.orange : Color.clear)
                .frame(height: 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .focusable()
        .focused(focusedSeasonID, equals: id)
        .focusEffectDisabled()
        .scaleEffect(visuallyFocused ? 1.05 : 1)
        .animation(.easeOut(duration: 0.15), value: visuallyFocused)
        .onTapGesture(perform: action)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

private struct SeasonNavigationBackModifier: ViewModifier {
    let enabled: Bool
    let action: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content.onExitCommand(perform: action)
        } else {
            content
        }
    }
}

private struct CinematicEpisodeRow: View {
    let item: MediaItem

    var body: some View {
        HStack(spacing: 30) {
            ArtworkView(
                remoteValue: item.episodeStill ?? item.backdrop ?? item.poster ?? item.seasonPoster,
                demoName: item.wideDemoArtworkName
            )
            .frame(width: 390, height: 210)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                Text(episodeLabel)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.72))

                Text(item.title)
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if let summary = item.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.system(size: 19, weight: .regular, design: .rounded))
                        .foregroundStyle(TaterTheme.secondaryText)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 24)

            VStack(alignment: .trailing, spacing: 16) {
                if let duration = item.durationDisplay, !duration.isEmpty {
                    Text(duration)
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                }

                if item.visibleProgress >= 0.95 {
                    Label("Watched", systemImage: "checkmark.circle")
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.76))
                } else if item.visibleProgress > 0 {
                    VStack(alignment: .trailing, spacing: 8) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.20))
                                Capsule()
                                    .fill(TaterTheme.orange)
                                    .frame(width: geometry.size.width * item.visibleProgress)
                            }
                        }
                        .frame(width: 190, height: 7)

                        Text("\(Int(item.visibleProgress * 100))% watched")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.68))
                    }
                }
            }
            .frame(width: 220, alignment: .trailing)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 246, alignment: .leading)
        .background(Color.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }

    private var episodeLabel: String {
        if let subtitle = item.subtitle, !subtitle.isEmpty { return subtitle.uppercased() }
        return "EPISODE"
    }
}

private struct LibraryContextHero: View {
    @EnvironmentObject private var store: PlayerStore

    let location: LibraryLocation
    let items: [MediaItem]
    let onFocusChange: (Bool) -> Void

    private var resumeItem: MediaItem? {
        if let nested = items.compactMap({ $0.resumeItem?.mediaItem }).first {
            return nested
        }
        return items.first {
            let progress = $0.progressPercent ?? 0
            return $0.streamURL?.isEmpty == false && progress > 0 && progress < 95
        }
    }

    var body: some View {
        HStack(spacing: 40) {
            ArtworkView(remoteValue: location.poster, demoName: location.demoArtworkName)
                .frame(width: 240, height: 350)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            VStack(alignment: .leading, spacing: 18) {
                Text(location.title)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .lineLimit(2)

                Text(metadataLine)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(TaterTheme.orange)

                if let summary = location.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.system(size: 24, weight: .regular, design: .rounded))
                        .foregroundStyle(TaterTheme.secondaryText)
                        .lineLimit(4)
                }

                if let resumeItem {
                    TaterActionButton(
                        prominent: true,
                        action: { Task { await store.play(resumeItem, resume: true) } },
                        onFocusChange: onFocusChange
                    ) {
                        Label(continueLabel(for: resumeItem), systemImage: "play.fill")
                    }
                }
            }

            Spacer(minLength: 20)
        }
        .padding(38)
        .frame(maxWidth: .infinity, minHeight: 390)
        .taterGlass(cornerRadius: 34)
        .focusSection()
    }

    private var metadataLine: String {
        let seasonCount = items.reduce(0) { $0 + ($1.mediaType?.lowercased() == "season" ? 1 : 0) }
        let episodeCount = items.reduce(0) { $0 + max($1.episodeCount, $1.leafCount) }
        if seasonCount > 0 {
            return "\(seasonCount) \(seasonCount == 1 ? "season" : "seasons")"
                + (episodeCount > 0 ? "  •  \(episodeCount) episodes" : "")
        }
        return "\(items.count) \(items.count == 1 ? "episode" : "episodes")"
    }

    private func continueLabel(for item: MediaItem) -> String {
        if let match = item.title.range(of: #"S\d{1,3}E\d{1,3}"#, options: .regularExpression) {
            return "Continue \(item.title[match].uppercased())"
        }
        return "Continue Episode"
    }
}

private struct SeasonCardView: View {
    let item: MediaItem

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            ArtworkView(
                remoteValue: item.seasonPoster ?? item.seriesPoster ?? item.poster,
                demoName: item.demoArtworkName
            )
            .frame(width: 248, height: 365)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(alignment: .bottom) { progressBar }

            VStack(alignment: .leading, spacing: 7) {
                Text(item.title)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(seasonMetadata)
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(item.resumeTitle == nil ? TaterTheme.secondaryText : TaterTheme.orange)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 70, alignment: .topLeading)
        }
        .frame(width: 248, height: 452, alignment: .topLeading)
    }

    @ViewBuilder
    private var progressBar: some View {
        if let progress = item.progressPercent, progress > 0 {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Color.white.opacity(0.2)
                    TaterTheme.orange
                        .frame(width: geometry.size.width * min(max(progress / 100, 0), 1))
                }
            }
            .frame(height: 7)
        }
    }

    private var seasonMetadata: String {
        if let resume = item.resumeTitle, !resume.isEmpty { return "Continue \(resume)" }
        let count = max(item.episodeCount, item.leafCount)
        return count > 0 ? "\(count) \(count == 1 ? "episode" : "episodes")" : "Season"
    }
}

private struct EpisodeCardView: View {
    let item: MediaItem

    var body: some View {
        HStack(spacing: 24) {
            ArtworkView(
                remoteValue: item.episodeStill ?? item.seasonPoster ?? item.seriesPoster ?? item.poster,
                demoName: item.demoArtworkName
            )
            .frame(width: 286, height: 166)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                Text(episodeMetadata)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle((item.progressPercent ?? 0) > 0 ? TaterTheme.orange : TaterTheme.secondaryText)

                Text(item.title)
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                if let summary = item.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.system(size: 18, weight: .regular, design: .rounded))
                        .foregroundStyle(TaterTheme.secondaryText)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 10)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 202, alignment: .leading)
        .taterGlass(cornerRadius: 24, interactive: true)
        .overlay(alignment: .bottom) {
            if let progress = item.progressPercent, progress > 0 {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Color.white.opacity(0.14)
                        TaterTheme.orange
                            .frame(width: geometry.size.width * min(max(progress / 100, 0), 1))
                    }
                }
                .frame(height: 6)
                .clipShape(Capsule())
                .padding(.horizontal, 22)
                .padding(.bottom, 10)
            }
        }
    }

    private var episodeMetadata: String {
        var parts = ["EPISODE"]
        if let duration = item.durationDisplay, !duration.isEmpty { parts.append(duration.uppercased()) }
        let progress = item.progressPercent ?? 0
        if progress >= 95 {
            parts.append("WATCHED")
        } else if progress > 0 {
            parts.append("RESUME")
        }
        return parts.joined(separator: "  •  ")
    }
}

private struct LibraryEmptyState: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "film.stack")
                .font(.system(size: 60, weight: .light))
                .foregroundStyle(TaterTheme.orange)
            Text(title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
            Text(message)
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .foregroundStyle(TaterTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding(40)
        .taterGlass(cornerRadius: 30)
    }
}

private struct LibraryGlowBackground: View {
    var body: some View {
        Color.black.ignoresSafeArea()
    }
}

private enum LibraryStage: Equatable {
    case movies
    case shows
    case seasons
    case episodes
    case generic

    init(location: LibraryLocation, items: [MediaItem]) {
        let locationType = location.mediaType?.lowercased() ?? ""
        let firstType = items.first?.mediaType?.lowercased() ?? ""
        if location.categoryID == "local-discover:series" && location.path.isEmpty {
            self = .shows
        } else if firstType == "episode" || locationType == "season" {
            self = .episodes
        } else if firstType == "season" || locationType == "show" || locationType == "series" {
            self = .seasons
        } else if location.categoryID == "local-discover:series" || firstType == "show" || firstType == "series" {
            self = .shows
        } else if location.categoryID == "local-discover:movies" || firstType == "movie" {
            self = .movies
        } else {
            self = .generic
        }
    }

    var showsHero: Bool { self == .seasons || self == .episodes }
}

extension MediaItem {
    var isBrowsableLibraryItem: Bool {
        guard streamURL?.isEmpty != false else { return false }
        let kind = mediaType?.lowercased() ?? ""
        return categoryID?.isEmpty == false && path != nil
            && ["show", "series", "season", "folder"].contains(kind)
    }
}

private extension Array where Element == MediaItem {
    var naturallySorted: [MediaItem] {
        sorted { left, right in
            let leftType = left.mediaType?.lowercased() ?? ""
            let rightType = right.mediaType?.lowercased() ?? ""
            guard leftType == rightType else {
                return left.title.localizedStandardCompare(right.title) == .orderedAscending
            }
            return (left.path ?? left.title).localizedStandardCompare(right.path ?? right.title) == .orderedAscending
        }
    }
}
