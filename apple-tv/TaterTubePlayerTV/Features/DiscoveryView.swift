import SwiftUI

struct DiscoveryView: View {
    @EnvironmentObject private var store: PlayerStore

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 30), count: 3)

    var body: some View {
        NavigationStack {
            ZStack {
                DiscoveryGlowBackground()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 44) {
                        hero

                        if !store.discoverCategories.isEmpty {
                            LazyVGrid(columns: columns, spacing: 30) {
                                ForEach(store.discoverCategories) { category in
                                    NavigationLink {
                                        DiscoveryTitlesView(category: category)
                                    } label: {
                                        DiscoveryCategoryCard(category: category)
                                    }
                                    .buttonStyle(.card)
                                }
                            }
                        } else if store.isDiscoverCatalogRefreshing {
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
                    .padding(.top, 36)
                    .padding(.bottom, 120)
                }
                .refreshable { await store.refreshDiscoverCatalog() }
            }
        }
        .task {
            await store.refreshDiscoverCatalog()
        }
    }

    private var hero: some View {
        HStack(spacing: 44) {
            VStack(alignment: .leading, spacing: 16) {
                Text("DISCOVER")
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .tracking(2.6)
                    .foregroundStyle(TaterTheme.orange)

                Text("Find your next favorite.")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Choose a collection, pick a title, then select the release that fits your screen and sound system.")
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .foregroundStyle(TaterTheme.secondaryText)
                    .lineLimit(3)
                    .frame(maxWidth: 980, alignment: .leading)
            }

            Spacer(minLength: 20)

            BundledImageView(name: "tater-hero-remote")
                .scaledToFit()
                .frame(width: 250, height: 210)
        }
        .padding(.horizontal, 48)
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity, minHeight: 260)
        .taterGlass(cornerRadius: 34)
    }
}

private struct DiscoveryCategoryCard: View {
    let category: DiscoverCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            BundledImageView(name: category.artworkName)
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            Text(category.title)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(category.detail ?? "Browse this collection")
                .font(.system(size: 19, weight: .medium, design: .rounded))
                .foregroundStyle(TaterTheme.secondaryText)
                .lineLimit(1)
        }
        .padding(14)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct DiscoveryTitlesView: View {
    @EnvironmentObject private var store: PlayerStore

    let category: DiscoverCategory

    private let columns = [GridItem(.adaptive(minimum: 238, maximum: 258), spacing: 34)]
    private var key: String { store.discoverFeedKey(for: category) }
    private var page: LibraryPage? { store.discoverPage(for: key) }

    var body: some View {
        ZStack {
            DiscoveryGlowBackground()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 42) {
                    categoryHero

                    if let page, !page.items.isEmpty {
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 38) {
                            ForEach(page.items) { item in
                                NavigationLink {
                                    DiscoveryResultsView(titleItem: item)
                                } label: {
                                    MediaCardView(item: item)
                                }
                                .buttonStyle(.card)
                            }
                        }
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
                .padding(.top, 28)
                .padding(.bottom, 120)
            }
            .refreshable { await store.loadDiscoverFeed(category, forceNetwork: true) }
        }
        .navigationTitle("")
        .task(id: key) {
            await store.loadDiscoverFeed(category)
        }
    }

    private var categoryHero: some View {
        HStack(spacing: 38) {
            BundledImageView(name: category.artworkName)
                .scaledToFill()
                .frame(width: 440, height: 205)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            VStack(alignment: .leading, spacing: 14) {
                Text(category.title)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(category.detail ?? "Browse this collection, then choose a release to play.")
                    .font(.system(size: 23, weight: .medium, design: .rounded))
                    .foregroundStyle(TaterTheme.secondaryText)
                    .lineLimit(3)
            }

            Spacer(minLength: 10)
        }
        .padding(28)
        .frame(maxWidth: .infinity, minHeight: 245, alignment: .leading)
        .taterGlass(cornerRadius: 32)
    }
}

private struct DiscoveryResultsView: View {
    @EnvironmentObject private var store: PlayerStore

    let titleItem: MediaItem

    @State private var preparedFiles: [DiscoverPreparedFile] = []
    @State private var selectedPreparedFile: DiscoverPreparedFile?
    @State private var showsFilePicker = false
    @State private var preparationError: String?

    private var key: String { store.discoverSearchKey(for: titleItem) }
    private var page: LibraryPage? { store.discoverPage(for: key) }

    var body: some View {
        ZStack {
            ArtworkView(
                remoteValue: titleItem.backdrop ?? titleItem.poster,
                demoName: titleItem.demoArtworkName
            )
            .ignoresSafeArea()
            .overlay(Color.black.opacity(0.76))
            .blur(radius: 12)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    titleHero

                    if let page, !page.items.isEmpty {
                        ForEach(page.items) { release in
                            Button {
                                prepare(release)
                            } label: {
                                DiscoveryReleaseRow(release: release)
                            }
                            .buttonStyle(.card)
                            .disabled(store.isPreparingDiscovery)
                        }
                    } else if store.loadingDiscoverPages.contains(key) {
                        DiscoveryStatePanel(
                            icon: "magnifyingglass",
                            title: "Finding releases…",
                            message: "Searching for the complete title now.",
                            showsProgress: true
                        )
                    } else if let error = store.discoverErrors[key] {
                        DiscoveryStatePanel(
                            icon: "exclamationmark.triangle.fill",
                            title: "Search didn’t finish",
                            message: error
                        )
                    } else {
                        DiscoveryStatePanel(
                            icon: "magnifyingglass",
                            title: "No releases found",
                            message: "Try another title or check the indexers configured on your server."
                        )
                    }
                }
                .padding(.horizontal, 100)
                .padding(.top, 30)
                .padding(.bottom, 120)
            }
            .refreshable { await store.searchDiscovery(for: titleItem, forceNetwork: true) }

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
        .task(id: key) {
            await store.searchDiscovery(for: titleItem)
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
        [release.sizeText ?? release.subtitle, release.files, release.grabs, release.category]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
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
                        Button {
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
                        .buttonStyle(.card)
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
