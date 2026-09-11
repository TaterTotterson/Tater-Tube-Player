import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var store: PlayerStore

    var body: some View {
        NavigationStack {
            ZStack {
                LibraryGlowBackground()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 54) {
                        collectionBar

                        ForEach(displayRows) { row in
                            LibraryShelf(row: row)
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
                }
                .refreshable { await store.refreshLibraryRows() }
            }
            .navigationDestination(for: LibraryLocation.self) { location in
                LibraryCollectionView(location: location)
            }
        }
        .task {
            if store.libraryRows.isEmpty {
                await store.refreshLibraryRows(showActivity: true)
            }
        }
    }

    private var collectionBar: some View {
        HStack(spacing: 24) {
            NavigationLink(value: LibraryLocation.allMovies) {
                Label("All Movies", systemImage: "film.fill")
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity, minHeight: 72)
            }
            .buttonStyle(.borderedProminent)
            .tint(TaterTheme.orange.opacity(0.82))

            NavigationLink(value: LibraryLocation.allShows) {
                Label("All TV Shows", systemImage: "tv.and.mediabox.fill")
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity, minHeight: 72)
            }
            .buttonStyle(.borderedProminent)
            .tint(TaterTheme.orange.opacity(0.82))
        }
        .padding(30)
        .taterGlass(cornerRadius: 30)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(row.title)
                .font(.system(size: 34, weight: .bold, design: .rounded))

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 28) {
                    ForEach(row.items) { item in
                        LibraryItemLink(item: item, parent: LibraryLocation(entry: row.entry))
                    }

                    NavigationLink(value: LibraryLocation(entry: row.entry)) {
                        VStack(spacing: 20) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 58, weight: .medium))
                            Text("See All")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .frame(width: 190, height: 365)
                        .taterGlass(cornerRadius: 22, interactive: true)
                    }
                    .buttonStyle(.card)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
            .contentMargins(.horizontal, -18, for: .scrollContent)
        }
    }
}

struct LibraryCollectionView: View {
    @EnvironmentObject private var store: PlayerStore

    let location: LibraryLocation

    private var page: LibraryPage? { store.libraryPage(for: location) }
    private var items: [MediaItem] { page?.items.naturallySorted ?? [] }
    private var stage: LibraryStage { LibraryStage(location: location, items: items) }

    var body: some View {
        ZStack {
            collectionBackground

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 44) {
                    if stage.showsHero {
                        LibraryContextHero(location: location, items: items)
                    }

                    if let page, page.items.isEmpty {
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
            }
            .refreshable { await store.loadLibraryPage(location, forceNetwork: true) }
        }
        .navigationTitle("")
        .task(id: location.cacheKey) {
            await store.loadLibraryPage(location)
        }
    }

    @ViewBuilder
    private var collectionBackground: some View {
        if stage.showsHero,
           location.backdrop != nil || location.poster != nil || location.demoArtworkName != nil {
            ArtworkView(
                remoteValue: location.backdrop ?? location.poster,
                demoName: location.demoArtworkName
            )
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.65))
                .blur(radius: 10)
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
                LibraryItemLink(item: item, parent: location)
            }
        }
    }

    private var episodeGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 690, maximum: 790), spacing: 34)],
            alignment: .leading,
            spacing: 30
        ) {
            ForEach(items) { item in
                Button {
                    store.openDetails(for: item)
                } label: {
                    EpisodeCardView(item: item)
                }
                .buttonStyle(.card)
            }
        }
    }
}

private struct LibraryItemLink: View {
    @EnvironmentObject private var store: PlayerStore

    let item: MediaItem
    let parent: LibraryLocation

    var body: some View {
        if item.isBrowsableLibraryItem {
            NavigationLink(value: LibraryLocation(item: item, parent: parent)) {
                if item.mediaType?.lowercased() == "season" {
                    SeasonCardView(item: item)
                } else {
                    MediaCardView(item: item)
                }
            }
            .buttonStyle(.card)
        } else {
            Button {
                store.openDetails(for: item)
            } label: {
                MediaCardView(item: item)
            }
            .buttonStyle(.card)
        }
    }
}

private struct LibraryContextHero: View {
    @EnvironmentObject private var store: PlayerStore

    let location: LibraryLocation
    let items: [MediaItem]

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
                    Button {
                        Task { await store.play(resumeItem, resume: true) }
                    } label: {
                        Label(continueLabel(for: resumeItem), systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TaterTheme.orange)
                }
            }

            Spacer(minLength: 20)
        }
        .padding(38)
        .frame(maxWidth: .infinity, minHeight: 390)
        .taterGlass(cornerRadius: 34)
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

            Text(item.title)
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(seasonMetadata)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundStyle(item.resumeTitle == nil ? TaterTheme.secondaryText : TaterTheme.orange)
                .lineLimit(1)
        }
        .frame(width: 248, alignment: .leading)
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
        ZStack {
            TaterTheme.background
            RadialGradient(
                colors: [TaterTheme.orange.opacity(0.16), Color.clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 900
            )
        }
        .ignoresSafeArea()
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
        if firstType == "episode" || locationType == "season" {
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

private extension MediaItem {
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
