import SwiftUI

struct TaterPicksView: View {
    @EnvironmentObject private var store: PlayerStore

    var body: some View {
        TaterPicksContent(speech: store.recommendationSpeech)
    }
}

private struct TaterPicksContent: View {
    @EnvironmentObject private var store: PlayerStore
    @ObservedObject var speech: RecommendationSpeechCoordinator

    @FocusState private var focusedPickID: String?
    @State private var spokenBatchID: String?
    @State private var libraryDestination: LibraryLocation?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 26), count: 4)

    var body: some View {
        NavigationStack {
            ZStack {
                picksBackground

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 38) {
                        hero

                        if !displayedRecommendations.isEmpty {
                            LazyVGrid(columns: columns, spacing: 28) {
                                ForEach(displayedRecommendations) { recommendation in
                                    Button {
                                        activate(recommendation)
                                    } label: {
                                        TaterPickCard(recommendation: recommendation)
                                    }
                                    .buttonStyle(.card)
                                    .focused($focusedPickID, equals: recommendation.id)
                                }
                            }
                        } else if store.isRecommendationsRefreshing {
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
                    .padding(.top, 34)
                    .padding(.bottom, 120)
                }
                .refreshable { await store.refreshRecommendations() }
            }
            .navigationDestination(item: $libraryDestination) { location in
                LibraryCollectionView(location: location)
            }
        }
        .task {
            queueSpeechIfPossible()
            await store.refreshRecommendations()
            queueSpeechIfPossible()
        }
        .onChange(of: store.recommendationBatch?.id) { _, _ in
            queueSpeechIfPossible()
        }
        .onDisappear {
            spokenBatchID = nil
            store.stopRecommendationSpeech()
        }
    }

    @ViewBuilder
    private var picksBackground: some View {
        if let artwork = focusedRecommendation?.launch.backdrop
            ?? focusedRecommendation?.launch.poster,
           !artwork.isEmpty {
            ArtworkView(remoteValue: artwork, demoName: focusedRecommendation?.launch.demoArtworkName)
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.82))
                .blur(radius: 18)
        } else {
            ZStack {
                TaterTheme.background
                RadialGradient(
                    colors: [TaterTheme.orange.opacity(0.18), .clear],
                    center: UnitPoint(x: 0.20, y: 0.06),
                    startRadius: 10,
                    endRadius: 920
                )
            }
            .ignoresSafeArea()
        }
    }

    private var hero: some View {
        ZStack {
            if let recommendation = focusedRecommendation {
                ArtworkView(
                    remoteValue: recommendation.launch.backdrop ?? recommendation.launch.poster,
                    demoName: recommendation.launch.demoArtworkName
                )
                .opacity(0.11)
            }

            HStack(spacing: 44) {
                VStack(alignment: .leading, spacing: 15) {
                    Text(heroEyebrow)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .tracking(2.4)
                        .foregroundStyle(TaterTheme.orange)

                    Text(heroTitle)
                        .font(.system(size: 45, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    if !heroMessage.isEmpty {
                        Text(heroMessage)
                            .font(.system(size: 24, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(4)
                    }

                    HStack(spacing: 11) {
                        if speech.state == .loading {
                            ProgressView()
                                .tint(TaterTheme.orange)
                        } else if speech.state == .speaking {
                            Image(systemName: "waveform")
                                .foregroundStyle(TaterTheme.orange)
                        }

                        Text(speechStatus)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(speechFailed ? Color.orange.opacity(0.78) : TaterTheme.secondaryText)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 18)

                BundledImageView(name: "tater-hero-remote")
                    .scaledToFit()
                    .frame(width: 250, height: 245)
            }
            .padding(.horizontal, 46)
            .padding(.vertical, 30)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .taterGlass(cornerRadius: 34)
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

    private var focusedRecommendation: TaterRecommendationItem? {
        guard let focusedPickID else { return nil }
        return displayedRecommendations.first { $0.id == focusedPickID }
    }

    private var assistantName: String {
        let name = store.recommendationBatch?.assistantName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "Tater" : name
    }

    private var heroEyebrow: String {
        focusedRecommendation == nil
            ? "A NOTE FROM \(assistantName.uppercased())"
            : "WHY \(assistantName.uppercased()) PICKED THIS"
    }

    private var heroTitle: String {
        focusedRecommendation?.title ?? "Tater Picks"
    }

    private var heroMessage: String {
        if let focusedRecommendation { return focusedRecommendation.reason }
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
            libraryDestination = LibraryLocation(
                categoryID: item.categoryID ?? "",
                title: item.title,
                sourceIndex: item.sourceIndex,
                path: item.path ?? "",
                backdrop: item.backdrop,
                poster: item.seriesPoster ?? item.seasonPoster ?? item.poster,
                summary: item.summary,
                mediaType: item.mediaType,
                demoArtworkName: item.demoArtworkName
            )
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

private struct TaterPickCard: View {
    let recommendation: TaterRecommendationItem

    private var item: MediaItem { recommendation.launch }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .topTrailing) {
                ArtworkView(
                    remoteValue: item.backdrop ?? item.episodeStill ?? item.poster,
                    demoName: item.demoArtworkName
                )
                .frame(maxWidth: .infinity)
                .frame(height: 185)
                .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))

                Text(String(format: "%02d", max(recommendation.rank, 1)))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(TaterTheme.orange.opacity(0.90), in: Capsule())
                    .padding(12)
            }

            Text("TATER PICK  •  \((item.mediaType ?? recommendation.mediaType ?? "video").uppercased())")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .tracking(1.0)
                .foregroundStyle(TaterTheme.orangeBright)

            Text(recommendation.title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(recommendation.reason)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .contentShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
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
