import SwiftUI

struct TaterPicksView: View {
    @EnvironmentObject private var store: PlayerStore
    @Binding var selectedTab: Int
    let onReturnToTopNavigation: () -> Void
    let contentFocusRequest: Int

    var body: some View {
        TaterPicksContent(
            speech: store.recommendationSpeech,
            selectedTab: $selectedTab,
            onReturnToTopNavigation: onReturnToTopNavigation,
            contentFocusRequest: contentFocusRequest
        )
    }
}

private struct TaterPicksContent: View {
    @EnvironmentObject private var store: PlayerStore
    @ObservedObject var speech: RecommendationSpeechCoordinator
    @Binding var selectedTab: Int
    let onReturnToTopNavigation: () -> Void
    let contentFocusRequest: Int

    @State private var highlightedPickID: String?
    @State private var spokenBatchID: String?
    @State private var navigationPath: [LibraryLocation] = []
    @FocusState private var entryCardHasFocus: Bool

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .topLeading) {
                TaterPicksBackdrop(item: highlightedRecommendation?.launch)

                VStack(alignment: .leading, spacing: 0) {
                    hero
                        .padding(.horizontal, 70)

                    if !displayedRecommendations.isEmpty {
                        VStack(alignment: .leading, spacing: 24) {
                            ForEach(pickRails) { rail in
                                TaterPicksShelf(
                                    rail: rail,
                                    highlightedPickID: $highlightedPickID,
                                    requestedEntryFocus: rail.id == pickRails.first?.id ? $entryCardHasFocus : nil,
                                    onSelect: activate
                                )
                            }
                        }
                        .padding(.horizontal, 70)
                        .padding(.top, 8)
                        .padding(.bottom, 82)
                    } else {
                        Group {
                            if store.isRecommendationsRefreshing {
                                TaterPicksStatePanel(
                                    icon: "wand.and.stars",
                                    title: "Tater is checking your shelves…",
                                    message: "Your next set of picks is on the way.",
                                    showsProgress: true
                                )
                            } else if let error = store.recommendationsError {
                                TaterPicksStatePanel(
                                    icon: "exclamationmark.triangle.fill",
                                    title: "Tater Picks couldn’t load",
                                    message: error
                                )
                            } else {
                                TaterPicksStatePanel(
                                    icon: "wand.and.stars",
                                    title: "Tater is still getting to know you",
                                    message: "Watch a few movies, shows, or Tube TV programs and Tater Core will prepare picks on its next schedule."
                                )
                            }
                        }
                        .padding(.horizontal, 78)
                        .padding(.top, 24)
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
        .onExitCommand {
            if navigationPath.isEmpty {
                onReturnToTopNavigation()
            } else {
                navigationPath.removeLast()
            }
        }
        .task {
            queueSpeechIfPossible()
            await store.refreshRecommendations()
            seedHighlightedPick()
            queueSpeechIfPossible()
        }
        .onChange(of: store.recommendationBatch?.id) { _, _ in
            seedHighlightedPick(reset: true)
            requestEntryFocusIfNeeded()
            queueSpeechIfPossible()
        }
        .onChange(of: contentFocusRequest) { _, _ in
            requestEntryFocusIfNeeded()
        }
        .onDisappear {
            spokenBatchID = nil
            store.stopRecommendationSpeech()
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(heroEyebrow)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .tracking(2.5)
                .foregroundStyle(TaterTheme.orangeBright)

            Text(heroTitle)
                .font(.system(size: 58, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)

            if let metadata = heroMetadata {
                Text(metadata)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
            }

            if !heroMessage.isEmpty {
                Text(heroMessage)
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(3)
                    .frame(maxWidth: 850, alignment: .leading)
            }

            if let recommendation = highlightedRecommendation {
                HStack(spacing: 10) {
                    ForEach(recommendation.launch.cinematicMetadataChips, id: \.self) { value in
                        Text(value)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.90))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 6))
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.32), lineWidth: 1.3)
                            }
                    }
                }
            }

            HStack(spacing: 10) {
                if speech.state == .loading {
                    ProgressView().tint(TaterTheme.orange)
                } else if speech.state == .speaking {
                    Image(systemName: "waveform").foregroundStyle(TaterTheme.orange)
                }

                Text(speechStatus)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(speechFailed ? Color.orange.opacity(0.78) : .white.opacity(0.58))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 320, alignment: .bottomLeading)
        .padding(.bottom, 18)
    }

    private var displayedRecommendations: [TaterRecommendationItem] {
        store.recommendations.filter { recommendation in
            let item = recommendation.launch
            let playable = item.streamURL?.isEmpty == false || item.nzbURL?.isEmpty == false
            let localTarget = item.categoryID?.lowercased().hasPrefix("local:") == true
                && item.path?.isEmpty == false
            return playable || localTarget || store.isDemo
        }
    }

    private var highlightedRecommendation: TaterRecommendationItem? {
        if let highlightedPickID,
           let recommendation = displayedRecommendations.first(where: { $0.id == highlightedPickID }) {
            return recommendation
        }
        return displayedRecommendations.first
    }

    private var assistantName: String {
        let name = store.recommendationBatch?.assistantName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "Tater" : name
    }

    private var heroEyebrow: String {
        highlightedRecommendation == nil
            ? "A NOTE FROM \(assistantName.uppercased())"
            : "WHY \(assistantName.uppercased()) PICKED THIS"
    }

    private var heroTitle: String {
        highlightedRecommendation?.title ?? "Tater Picks"
    }

    private var heroMessage: String {
        if let highlightedRecommendation { return highlightedRecommendation.reason }
        let summary = store.recommendationBatch?.summary.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !summary.isEmpty { return summary }
        return store.recommendationBatch?.picksBriefing?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var speechStatus: String {
        switch speech.state {
        case .loading:
            return "Getting \(assistantName)’s voice…"
        case .speaking:
            return "\(assistantName) is speaking"
        case .failed(let message):
            return message
        case .idle:
            let count = displayedRecommendations.count
            return count == 1 ? "1 pick for you" : "\(count) picks for you"
        }
    }

    private var speechFailed: Bool {
        if case .failed = speech.state { return true }
        return false
    }

    private var heroMetadata: String? {
        guard let item = highlightedRecommendation?.launch else { return nil }
        let values = [
            item.date,
            item.contentRating,
            item.durationDisplay
        ].compactMap { value -> String? in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        return values.isEmpty ? nil : values.joined(separator: "  •  ")
    }

    private var pickRails: [TaterPickRail] {
        let sorted = displayedRecommendations.sorted { $0.rank < $1.rank }
        let moviePicks = sorted.filter { isMovie($0.launch) }
        let seriesPicks = sorted.filter { isSeries($0.launch) }
        let classifiedIDs = Set((moviePicks + seriesPicks).map(\.id))
        let otherPicks = sorted.filter { !classifiedIDs.contains($0.id) }

        if !moviePicks.isEmpty && !seriesPicks.isEmpty {
            return [
                TaterPickRail(id: "movie-picks", title: "MOVIE PICKS", detail: "Hand-picked for movie night", items: moviePicks + otherPicks),
                TaterPickRail(id: "series-picks", title: "SERIES PICKS", detail: "Your next great series", items: seriesPicks)
            ]
        }

        guard sorted.count > 1 else {
            return [TaterPickRail(id: "top-picks", title: "TATER’S PICKS", detail: "Chosen for you", items: sorted)]
        }
        let splitIndex = max(1, Int(ceil(Double(sorted.count) / 2.0)))
        return [
            TaterPickRail(id: "top-picks", title: "TATER’S TOP PICKS", detail: "Start with these", items: Array(sorted.prefix(splitIndex))),
            TaterPickRail(id: "more-picks", title: "MORE FOR YOU", detail: "Keep exploring", items: Array(sorted.dropFirst(splitIndex)))
        ].filter { !$0.items.isEmpty }
    }

    private func isMovie(_ item: MediaItem) -> Bool {
        ["movie", "film"].contains((item.mediaType ?? item.type ?? "").lowercased())
    }

    private func isSeries(_ item: MediaItem) -> Bool {
        ["show", "series", "tv", "tvshow", "season", "episode"].contains((item.mediaType ?? item.type ?? "").lowercased())
    }

    private func seedHighlightedPick(reset: Bool = false) {
        if reset || highlightedPickID == nil {
            highlightedPickID = displayedRecommendations.first?.id
        }
    }

    private func requestEntryFocusIfNeeded() {
        guard pickRails.first?.items.isEmpty == false else { return }
        Task { @MainActor in
            await Task.yield()
            entryCardHasFocus = true
        }
    }

    private func queueSpeechIfPossible() {
        guard !store.isDemo,
              let batch = store.recommendationBatch,
              !batch.id.isEmpty,
              !displayedRecommendations.isEmpty,
              spokenBatchID != batch.id
        else { return }
        spokenBatchID = batch.id
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            guard spokenBatchID == batch.id else { return }
            store.beginRecommendationSpeech(batchID: batch.id)
        }
    }

    private func activate(_ recommendation: TaterRecommendationItem) {
        store.stopRecommendationSpeech()
        let item = recommendation.launch
        if isBrowsable(item) {
            navigationPath.append(LibraryLocation(
                categoryID: item.categoryID ?? "",
                title: item.title,
                sourceIndex: item.sourceIndex,
                path: item.path ?? "",
                backdrop: item.backdrop,
                poster: item.seriesPoster ?? item.seasonPoster ?? item.poster,
                summary: item.summary,
                mediaType: item.mediaType,
                demoArtworkName: item.demoArtworkName
            ))
        } else {
            store.openDetails(for: item)
        }
    }

    private func isBrowsable(_ item: MediaItem) -> Bool {
        guard item.streamURL?.isEmpty != false, item.nzbURL?.isEmpty != false else { return false }
        let kind = item.mediaType?.lowercased() ?? ""
        return item.categoryID?.isEmpty == false
            && item.path?.isEmpty == false
            && ["show", "series", "season", "folder"].contains(kind)
    }
}

private struct TaterPickRail: Identifiable {
    let id: String
    let title: String
    let detail: String
    let items: [TaterRecommendationItem]
}

private struct TaterPicksShelf: View {
    let rail: TaterPickRail
    @Binding var highlightedPickID: String?
    let requestedEntryFocus: FocusState<Bool>.Binding?
    let onSelect: (TaterRecommendationItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .lastTextBaseline) {
                Text(rail.title)
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .tracking(3)
                Spacer()
                Text(rail.detail)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 24) {
                    ForEach(rail.items) { recommendation in
                        TaterCardButton(
                            cornerRadius: 22,
                            action: { onSelect(recommendation) },
                            onFocusChange: { focused in
                                guard focused else { return }
                                var transaction = Transaction()
                                transaction.animation = nil
                                transaction.disablesAnimations = true
                                withTransaction(transaction) {
                                    highlightedPickID = recommendation.id
                                }
                            },
                            requestedFocus: recommendation.id == rail.items.first?.id ? requestedEntryFocus : nil
                        ) {
                            TaterPickCard(recommendation: recommendation)
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

private struct TaterPicksBackdrop: View {
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
                .frame(height: 760, alignment: .top)
                .clipped()
            }

            LinearGradient(
                colors: [Color.black.opacity(0.97), Color.black.opacity(0.56), Color.black.opacity(0.08)],
                startPoint: .leading,
                endPoint: .trailing
            )
            LinearGradient(
                colors: [Color.black.opacity(0.04), Color.black.opacity(0.22), Color.black.opacity(0.96), .black],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

private struct TaterPickCard: View {
    let recommendation: TaterRecommendationItem

    private var item: MediaItem { recommendation.launch }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ArtworkView(
                remoteValue: item.wideShelfArtwork,
                demoName: item.wideDemoArtworkName
            )

            LinearGradient(
                colors: [.clear, Color.black.opacity(0.18), Color.black.opacity(0.94)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 6) {
                Text("TATER PICK  •  \((item.mediaType ?? recommendation.mediaType ?? "video").uppercased())")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .tracking(1.25)
                    .foregroundStyle(TaterTheme.orangeBright)

                Text(recommendation.title)
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(recommendation.reason)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
            }
            .padding(20)

        }
        .frame(width: 360, height: 203)
        .overlay(alignment: .topTrailing) {
            Text(String(format: "%02d", max(recommendation.rank, 1)))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(TaterTheme.orange.opacity(0.90), in: Capsule())
                .padding(12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct TaterPicksStatePanel: View {
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
                .frame(maxWidth: 840)
        }
        .padding(42)
        .frame(maxWidth: .infinity, minHeight: 270)
        .taterGlass(cornerRadius: 30)
    }
}
