import SwiftUI

private struct DiscoveryRoute: Hashable {
    enum Kind: Hashable {
        case category
        case title
    }

    let kind: Kind
    let id: String
    let category: DiscoverCategory?
    let titleItem: MediaItem?

    static func category(_ category: DiscoverCategory) -> DiscoveryRoute {
        DiscoveryRoute(kind: .category, id: "category:\(category.id)", category: category, titleItem: nil)
    }

    static func title(_ item: MediaItem) -> DiscoveryRoute {
        DiscoveryRoute(kind: .title, id: "title:\(item.id)", category: nil, titleItem: item)
    }

    static func == (lhs: DiscoveryRoute, rhs: DiscoveryRoute) -> Bool {
        lhs.kind == rhs.kind && lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(kind)
        hasher.combine(id)
    }
}

struct DiscoveryView: View {
    @EnvironmentObject private var store: PlayerStore
    @Binding var selectedTab: Int
    let onReturnToTopNavigation: () -> Void
    let contentFocusRequest: Int
    @State private var navigationPath: [DiscoveryRoute] = []
    @State private var highlightedCategoryID: String?
    @State private var selectedTitleFocusID: String?
    @State private var titleFocusRestoreRequest = 0
    @State private var isHandlingBack = false
    @FocusState private var entryCardHasFocus: Bool

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .topLeading) {
                DiscoveryCollectionBackdrop(category: highlightedCategory)

                VStack(alignment: .leading, spacing: 0) {
                    hero
                        .padding(.horizontal, 70)

                    if !store.discoverCategories.isEmpty {
                        VStack(alignment: .leading, spacing: 24) {
                            if !movieCategories.isEmpty {
                                DiscoveryCategoryShelf(
                                    title: "MOVIES",
                                    categories: movieCategories,
                                    highlightedCategoryID: $highlightedCategoryID,
                                    requestedEntryFocus: movieCategories.first?.id == firstCategoryID ? $entryCardHasFocus : nil,
                                    onSelect: { navigationPath.append(.category($0)) }
                                )
                            }

                            if !seriesCategories.isEmpty {
                                DiscoveryCategoryShelf(
                                    title: "SERIES",
                                    categories: seriesCategories,
                                    highlightedCategoryID: $highlightedCategoryID,
                                    requestedEntryFocus: movieCategories.isEmpty ? $entryCardHasFocus : nil,
                                    onSelect: { navigationPath.append(.category($0)) }
                                )
                            }
                        }
                        .padding(.horizontal, 70)
                        .padding(.top, 8)
                        .padding(.bottom, 82)
                    } else {
                        Group {
                            if store.isDiscoverCatalogRefreshing {
                            DiscoveryStatePanel(
                                icon: "sparkles.tv.fill",
                                title: "Finding something good…",
                                message: "Loading Discover from your Tater Tube Server.",
                                showsProgress: true
                            )
                            } else if let error = store.discoverErrors["catalog"] {
                                DiscoveryStatePanel(
                                    icon: "exclamationmark.triangle.fill",
                                    title: "Discover isn’t available",
                                    message: error
                                )
                            } else {
                                DiscoveryStatePanel(
                                    icon: "sparkles.tv.fill",
                                    title: "Nothing to discover yet",
                                    message: "Set up NZB streaming on your Tater Tube Server to browse new movies and television."
                                )
                            }
                        }
                        .padding(.horizontal, 78)
                        .padding(.top, 24)
                    }
                }
            }
            .navigationDestination(for: DiscoveryRoute.self) { route in
                switch route.kind {
                case .category:
                    if let category = route.category {
                        DiscoveryTitlesView(
                            category: category,
                            requestedFocusID: selectedTitleFocusID,
                            focusRestoreRequest: titleFocusRestoreRequest
                        ) { item in
                            selectedTitleFocusID = item.id
                            navigationPath.append(.title(item))
                        }
                    }
                case .title:
                    if let item = route.titleItem {
                        DiscoveryResultsView(titleItem: item, onBack: navigateBack)
                    }
                }
            }
        }
        .onExitCommand(perform: navigateBack)
        .task {
            await store.refreshDiscoverCatalog()
            seedHighlightedCategory()
        }
        .onChange(of: store.discoverCategories) { _, _ in
            seedHighlightedCategory()
            requestEntryFocusIfNeeded()
        }
        .onChange(of: contentFocusRequest) { _, _ in
            requestEntryFocusIfNeeded()
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(discoveryEyebrow)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .tracking(2.5)
                .foregroundStyle(TaterTheme.orangeBright)

            Text(highlightedCategory?.title ?? "Find your next favorite.")
                .font(.system(size: 60, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(highlightedCategory?.detail ?? "Choose a collection, pick a title, then select the release that fits your screen and sound system.")
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(3)
                .frame(maxWidth: 820, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: 300, alignment: .bottomLeading)
        .padding(.bottom, 22)
    }

    private var movieCategories: [DiscoverCategory] {
        store.discoverCategories.filter { !isSeriesCategory($0) }
    }

    private var seriesCategories: [DiscoverCategory] {
        store.discoverCategories.filter { isSeriesCategory($0) }
    }

    private var firstCategoryID: String? {
        movieCategories.first?.id ?? seriesCategories.first?.id
    }

    private var highlightedCategory: DiscoverCategory? {
        if let highlightedCategoryID,
           let category = store.discoverCategories.first(where: { $0.id == highlightedCategoryID }) {
            return category
        }
        return movieCategories.first ?? seriesCategories.first
    }

    private var discoveryEyebrow: String {
        switch highlightedCategory?.artworkName {
        case "popular-movies": return "WHAT EVERYONE’S WATCHING"
        case "new-movies": return "FRESH MOVIE RELEASES"
        case "featured-movies": return "HIGHLY RATED MOVIES"
        case "popular-tv": return "SERIES PEOPLE LOVE"
        case "new-tv": return "NEW & RETURNING SERIES"
        case "featured-tv": return "HIGHLY RATED SERIES"
        default: return "DISCOVER"
        }
    }

    private func isSeriesCategory(_ category: DiscoverCategory) -> Bool {
        category.category?.lowercased() == "series"
            || category.id.lowercased().hasPrefix("series:")
            || category.artworkName.hasSuffix("-tv")
    }

    private func seedHighlightedCategory() {
        guard highlightedCategoryID == nil else { return }
        highlightedCategoryID = firstCategoryID
    }

    private func requestEntryFocusIfNeeded() {
        guard firstCategoryID != nil else { return }
        Task { @MainActor in
            await Task.yield()
            entryCardHasFocus = true
        }
    }

    private func navigateBack() {
        guard !isHandlingBack else { return }
        isHandlingBack = true

        if navigationPath.isEmpty {
            onReturnToTopNavigation()
        } else {
            let removedRoute = navigationPath.removeLast()
            if removedRoute.kind == .title {
                titleFocusRestoreRequest &+= 1
            }
        }

        Task { @MainActor in
            await Task.yield()
            isHandlingBack = false
        }
    }
}

private struct DiscoveryCategoryShelf: View {
    let title: String
    let categories: [DiscoverCategory]
    @Binding var highlightedCategoryID: String?
    let requestedEntryFocus: FocusState<Bool>.Binding?
    let onSelect: (DiscoverCategory) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(title)
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .tracking(3)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 24) {
                    ForEach(categories) { category in
                        TaterCardButton(
                            cornerRadius: 22,
                            action: { onSelect(category) },
                            onFocusChange: { focused in
                                guard focused else { return }
                                var transaction = Transaction()
                                transaction.animation = nil
                                transaction.disablesAnimations = true
                                withTransaction(transaction) {
                                    highlightedCategoryID = category.id
                                }
                            },
                            requestedFocus: category.id == categories.first?.id ? requestedEntryFocus : nil
                        ) {
                            DiscoveryCategoryCard(category: category)
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 18)
            }
            .scrollClipDisabled()
            .contentMargins(.horizontal, -30, for: .scrollContent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .focusSection()
    }
}

private struct DiscoveryCategoryCard: View {
    let category: DiscoverCategory

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            DiscoveryCollectionArtwork(category: category)

            LinearGradient(
                colors: [.clear, Color.black.opacity(0.18), Color.black.opacity(0.94)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 7) {
                Text(categoryEyebrow)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(TaterTheme.orangeBright)

                Text(category.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(category.detail ?? "Browse this collection")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.70))
                    .lineLimit(1)
            }
            .padding(21)
        }
        .frame(width: 500, height: 172)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var categoryEyebrow: String {
        switch category.artworkName {
        case "popular-movies", "popular-tv": return "TRENDING NOW"
        case "new-movies": return "FRESH RELEASES"
        case "new-tv": return "NEW & RETURNING"
        default: return "HIGHLY RATED"
        }
    }
}

private struct DiscoveryCollectionBackdrop: View {
    let category: DiscoverCategory?

    var body: some View {
        ZStack {
            DiscoveryCollectionArtwork(category: category)
                .ignoresSafeArea()

            LinearGradient(
                colors: [Color.black.opacity(0.97), Color.black.opacity(0.58), Color.black.opacity(0.10)],
                startPoint: .leading,
                endPoint: .trailing
            )

            LinearGradient(
                colors: [Color.black.opacity(0.02), Color.black.opacity(0.28), Color.black.opacity(0.96), .black],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

private struct DiscoveryCollectionArtwork: View {
    let category: DiscoverCategory?

    private var colors: [Color] {
        switch category?.artworkName {
        case "new-movies": return [Color(red: 0.05, green: 0.08, blue: 0.16), Color(red: 0.25, green: 0.22, blue: 0.47), Color(red: 0.32, green: 0.14, blue: 0.36)]
        case "featured-movies": return [Color(red: 0.08, green: 0.07, blue: 0.03), Color(red: 0.42, green: 0.29, blue: 0.08), Color(red: 0.54, green: 0.27, blue: 0.06)]
        case "popular-tv": return [Color(red: 0.03, green: 0.10, blue: 0.09), Color(red: 0.09, green: 0.34, blue: 0.30), Color(red: 0.10, green: 0.35, blue: 0.39)]
        case "new-tv": return [Color(red: 0.05, green: 0.06, blue: 0.13), Color(red: 0.25, green: 0.18, blue: 0.42), Color(red: 0.42, green: 0.16, blue: 0.35)]
        case "featured-tv": return [Color(red: 0.11, green: 0.04, blue: 0.05), Color(red: 0.43, green: 0.15, blue: 0.19), Color(red: 0.50, green: 0.22, blue: 0.16)]
        default: return [Color(red: 0.03, green: 0.08, blue: 0.11), Color(red: 0.18, green: 0.38, blue: 0.44), Color(red: 0.54, green: 0.24, blue: 0.08)]
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
            RadialGradient(
                colors: [Color.white.opacity(0.24), .clear],
                center: UnitPoint(x: 0.78, y: 0.22),
                startRadius: 8,
                endRadius: 420
            )
            RadialGradient(
                colors: [TaterTheme.orange.opacity(0.22), .clear],
                center: UnitPoint(x: 0.62, y: 0.56),
                startRadius: 8,
                endRadius: 500
            )
        }
    }
}

private struct DiscoveryTitlesView: View {
    @EnvironmentObject private var store: PlayerStore

    let category: DiscoverCategory
    let requestedFocusID: String?
    let focusRestoreRequest: Int
    let onSelectTitle: (MediaItem) -> Void
    @FocusState private var focusedTitleID: String?

    private let columns = [GridItem(.adaptive(minimum: 238, maximum: 258), spacing: 34)]
    private var key: String { store.discoverFeedKey(for: category) }
    private var page: LibraryPage? { store.discoverPage(for: key) }

    var body: some View {
        ZStack {
            DiscoveryGlowBackground()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 42) {
                    if let page, !page.items.isEmpty {
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 38) {
                            ForEach(page.items) { item in
                                TaterCardButton(cornerRadius: 20, action: {
                                    onSelectTitle(item)
                                }) {
                                    MediaCardView(item: item)
                                }
                                .focused($focusedTitleID, equals: item.id)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .focusSection()
                    } else if store.loadingDiscoverPages.contains(key) {
                        DiscoveryStatePanel(
                            icon: "sparkles",
                            title: "Loading \(category.title)…",
                            message: "Your cached collection appears first whenever one is available.",
                            showsProgress: true
                        )
                    } else if let error = store.discoverErrors[key] {
                        DiscoveryStatePanel(
                            icon: "exclamationmark.triangle.fill",
                            title: "Couldn’t load this collection",
                            message: error
                        )
                    } else {
                        DiscoveryStatePanel(
                            icon: "film.stack",
                            title: "Nothing here right now",
                            message: "Your server did not return any titles for this collection."
                        )
                    }
                }
                .padding(.horizontal, 78)
                .padding(.top, 52)
                .padding(.bottom, 120)
            }
            .refreshable { await store.loadDiscoverFeed(category, forceNetwork: true) }
        }
        .navigationTitle("")
        .task(id: key) {
            await store.loadDiscoverFeed(category)
        }
        .onChange(of: focusRestoreRequest) { _, _ in
            restoreSelectedTitleFocus()
        }
    }

    private func restoreSelectedTitleFocus() {
        guard let requestedFocusID,
              page?.items.contains(where: { $0.id == requestedFocusID }) == true else { return }

        Task { @MainActor in
            await Task.yield()
            focusedTitleID = requestedFocusID
        }
    }

}

private struct DiscoveryResultsView: View {
    @EnvironmentObject private var store: PlayerStore

    let titleItem: MediaItem

    @State private var preparedFiles: [DiscoverPreparedFile] = []
    @State private var selectedPreparedFile: DiscoverPreparedFile?
    @State private var showsFilePicker = false
    @State private var preparationError: String?
    @FocusState private var statePanelHasFocus: Bool

    let onBack: () -> Void

    private var key: String { store.discoverSearchKey(for: titleItem) }
    private var page: LibraryPage? { store.discoverPage(for: key) }

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                ArtworkView(
                    remoteValue: titleItem.backdrop ?? titleItem.poster,
                    demoName: titleItem.demoArtworkName
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .overlay(Color.black.opacity(0.76))
                .blur(radius: 12)
            }
            .ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    titleHero

                    if let page, !page.items.isEmpty {
                        ForEach(page.items) { release in
                            TaterCardButton(cornerRadius: 24) {
                                prepare(release)
                            } label: {
                                DiscoveryReleaseRow(release: release)
                            }
                            .disabled(store.isPreparingDiscovery)
                        }
                    } else if store.loadingDiscoverPages.contains(key) {
                        DiscoveryStatePanel(
                            icon: "magnifyingglass",
                            title: "Finding releases…",
                            message: "Searching for the complete title now.",
                            showsProgress: true
                        )
                        .focusable()
                        .focused($statePanelHasFocus)
                        .focusEffectDisabled()
                    } else if let error = store.discoverErrors[key] {
                        DiscoveryStatePanel(
                            icon: "exclamationmark.triangle.fill",
                            title: "Search didn’t finish",
                            message: error
                        )
                        .focusable()
                        .focused($statePanelHasFocus)
                        .focusEffectDisabled()
                    } else {
                        DiscoveryStatePanel(
                            icon: "magnifyingglass",
                            title: "No releases found",
                            message: "Try another title or check the indexers configured on your server."
                        )
                        .focusable()
                        .focused($statePanelHasFocus)
                        .focusEffectDisabled()
                    }
                }
                .padding(.horizontal, 100)
                .padding(.top, 30)
                .padding(.bottom, 120)
            }
            .refreshable {
                await store.searchDiscovery(for: titleItem, forceNetwork: true)
            }

            if store.isPreparingDiscovery {
                Color.black.opacity(0.50)
                    .ignoresSafeArea()

                VStack(spacing: 22) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(TaterTheme.orange)
                    Text("Preparing your stream…")
                        .font(.system(size: 31, weight: .bold, design: .rounded))
                    Text("Tater Tube Server is checking the release and finding its playable files.")
                        .font(.system(size: 21, weight: .medium, design: .rounded))
                        .foregroundStyle(TaterTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 58)
                .padding(.vertical, 42)
                .frame(maxWidth: 700)
                .taterGlass(cornerRadius: 32)
            }
        }
        .navigationTitle("")
        .onExitCommand(perform: onBack)
        .task(id: key) {
            await store.searchDiscovery(for: titleItem)
            requestStatePanelFocusIfNeeded()
        }
        .onChange(of: store.loadingDiscoverPages.contains(key)) { _, isLoading in
            if !isLoading { requestStatePanelFocusIfNeeded() }
        }
        .sheet(isPresented: $showsFilePicker, onDismiss: playSelectedFile) {
            DiscoveryFilePicker(files: preparedFiles) { file in
                selectedPreparedFile = file
                showsFilePicker = false
            }
        }
        .alert("Couldn’t prepare this stream", isPresented: errorIsPresented) {
            Button("OK", role: .cancel) { preparationError = nil }
        } message: {
            Text(preparationError ?? "Please try another release.")
        }
    }

    private var titleHero: some View {
        HStack(spacing: 34) {
            ArtworkView(remoteValue: titleItem.poster, demoName: titleItem.demoArtworkName)
                .frame(width: 180, height: 265)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(alignment: .leading, spacing: 13) {
                Text(titleItem.title)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text("Choose a release")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(TaterTheme.orange)

                if let summary = titleItem.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.system(size: 21, weight: .medium, design: .rounded))
                        .foregroundStyle(TaterTheme.secondaryText)
                        .lineLimit(4)
                }
            }

            Spacer(minLength: 12)
        }
        .padding(28)
        .frame(maxWidth: .infinity, minHeight: 305, alignment: .leading)
        .taterGlass(cornerRadius: 32)
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { preparationError != nil },
            set: { if !$0 { preparationError = nil } }
        )
    }

    private func requestStatePanelFocusIfNeeded() {
        guard page?.items.isEmpty != false else { return }
        Task { @MainActor in
            await Task.yield()
            statePanelHasFocus = true
        }
    }

    private func prepare(_ release: MediaItem) {
        Task {
            do {
                let files = try await store.prepareDiscovery(release: release, sourceTitle: titleItem)
                if files.count == 1, let onlyFile = files.first {
                    await store.playPreparedDiscovery(onlyFile, resume: false)
                } else {
                    preparedFiles = files
                    showsFilePicker = true
                }
            } catch {
                preparationError = error.localizedDescription
            }
        }
    }

    private func playSelectedFile() {
        guard let file = selectedPreparedFile else { return }
        selectedPreparedFile = nil
        Task { await store.playPreparedDiscovery(file, resume: false) }
    }
}

private struct DiscoveryReleaseRow: View {
    let release: MediaItem

    var body: some View {
        HStack(spacing: 26) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(TaterTheme.orange.opacity(0.14))
                Image(systemName: "play.square.stack.fill")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(TaterTheme.orange)
            }
            .frame(width: 112, height: 92)

            VStack(alignment: .leading, spacing: 12) {
                Text(release.title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(releaseMetadata.joined(separator: "  •  "))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(TaterTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 20)

            Image(systemName: "chevron.right")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(TaterTheme.orange)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .taterGlass(cornerRadius: 26, interactive: true)
    }

    private var releaseMetadata: [String] {
        [
            nonempty(release.sizeText ?? release.subtitle),
            countLabel(release.files, singular: "file", plural: "files"),
            countLabel(release.grabs, singular: "grab", plural: "grabs")
        ]
        .compactMap { $0 }
    }

    private func nonempty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func countLabel(_ value: String?, singular: String, plural: String) -> String? {
        guard let value = nonempty(value) else { return nil }
        let lowercaseValue = value.lowercased()
        if lowercaseValue.contains(singular) || lowercaseValue.contains(plural) {
            return value
        }

        return "\(value) \(value == "1" ? singular : plural)"
    }
}

private struct DiscoveryFilePicker: View {
    let files: [DiscoverPreparedFile]
    let onSelect: (DiscoverPreparedFile) -> Void

    var body: some View {
        ZStack {
            DiscoveryGlowBackground()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Choose a file")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                        Text("This release contains more than one playable video.")
                            .font(.system(size: 23, weight: .medium, design: .rounded))
                            .foregroundStyle(TaterTheme.secondaryText)
                    }
                    .padding(.bottom, 10)

                    ForEach(files) { file in
                        TaterCardButton(cornerRadius: 24) {
                            onSelect(file)
                        } label: {
                            HStack(spacing: 24) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(TaterTheme.orange)
                                Text(file.filename)
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 12)
                            }
                            .padding(.horizontal, 30)
                            .padding(.vertical, 24)
                            .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
                                .taterGlass(cornerRadius: 24, interactive: true)
                        }
                    }
                }
                .padding(.horizontal, 110)
                .padding(.vertical, 70)
            }
        }
    }
}

private struct DiscoveryStatePanel: View {
    let icon: String
    let title: String
    let message: String
    var showsProgress = false

    var body: some View {
        VStack(spacing: 18) {
            if showsProgress {
                ProgressView()
                    .controlSize(.large)
                    .tint(TaterTheme.orange)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 58, weight: .light))
                    .foregroundStyle(TaterTheme.orange)
            }
            Text(title)
                .font(.system(size: 31, weight: .bold, design: .rounded))
            Text(message)
                .font(.system(size: 21, weight: .medium, design: .rounded))
                .foregroundStyle(TaterTheme.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 800)
        }
        .padding(42)
        .frame(maxWidth: .infinity, minHeight: 270)
        .taterGlass(cornerRadius: 30)
    }
}

private struct DiscoveryGlowBackground: View {
    var body: some View {
        ZStack {
            TaterTheme.background
            RadialGradient(
                colors: [TaterTheme.orange.opacity(0.17), .clear],
                center: UnitPoint(x: 0.22, y: 0.08),
                startRadius: 10,
                endRadius: 920
            )
        }
        .ignoresSafeArea()
    }
}
