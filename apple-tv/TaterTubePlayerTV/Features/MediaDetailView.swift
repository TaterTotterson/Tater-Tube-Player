import SwiftUI

struct MediaDetailView: View {
    @EnvironmentObject private var store: PlayerStore
    @Namespace private var popupFocusScope
    @FocusState private var resumeHasFocus: Bool
    @FocusState private var playHasFocus: Bool
    @FocusState private var clearHasFocus: Bool

    let item: MediaItem

    var body: some View {
        HStack(spacing: 42) {
            ArtworkView(remoteValue: detailPoster, demoName: item.demoArtworkName)
                .frame(width: 310, height: 460)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            VStack(alignment: .leading, spacing: 16) {
                Text(item.title)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .lineLimit(2)

                if let metadata = metadataLine {
                    Text(metadata)
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(TaterTheme.orange)
                        .lineLimit(1)
                }

                if let tagline = item.tagline, !tagline.isEmpty {
                    Text(tagline)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.88))
                        .italic()
                        .lineLimit(1)
                }

                if let summary = item.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.system(size: 22, weight: .regular, design: .rounded))
                        .foregroundStyle(TaterTheme.secondaryText)
                        .lineLimit(3)
                }

                if store.isPreparingDiscovery {
                    HStack(spacing: 14) {
                        ProgressView()
                            .tint(TaterTheme.orange)
                        Text("Preparing your Discover stream…")
                            .font(.system(size: 21, weight: .semibold, design: .rounded))
                            .foregroundStyle(TaterTheme.secondaryText)
                    }
                }

                HStack(spacing: 20) {
                    if item.resumeOffsetMS > 0 {
                        TaterActionButton(
                            action: {
                                Task { await store.play(item, resume: true) }
                            },
                            requestedFocus: $resumeHasFocus
                        ) {
                            Label("Resume", systemImage: "play.fill")
                        }
                        .disabled(!hasPlayableSource || store.isPreparingDiscovery)
                        .prefersDefaultFocus(true, in: popupFocusScope)
                    }

                    TaterActionButton(
                        action: {
                            Task { await store.play(item, resume: false) }
                        },
                        requestedFocus: $playHasFocus
                    ) {
                        Label(
                            store.isDemo
                                ? "Play Demo"
                                : (item.resumeOffsetMS > 0 ? "Start Over" : "Play"),
                            systemImage: "play"
                        )
                    }
                    .disabled(!hasPlayableSource || store.isPreparingDiscovery)
                    .prefersDefaultFocus(item.resumeOffsetMS <= 0, in: popupFocusScope)

                    if item.resumeOffsetMS > 0 {
                        TaterActionButton(
                            action: {
                                Task { await store.clearProgress(for: item) }
                            },
                            requestedFocus: $clearHasFocus
                        ) {
                            Image(systemName: "arrow.counterclockwise")
                                .accessibilityLabel("Clear watch progress")
                        }
                        .disabled(store.isDemo || store.isPreparingDiscovery)
                    }
                }
                .padding(.top, 8)
                .focusSection()

                Spacer(minLength: 42)
            }
            .frame(maxWidth: 780, minHeight: 460, maxHeight: 460, alignment: .topLeading)
        }
        .padding(.horizontal, 44)
        .padding(.vertical, 36)
        .taterGlass(cornerRadius: 34)
        .frame(maxWidth: 1220)
        .padding(.horizontal, 80)
        .padding(.vertical, 90)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .focusScope(popupFocusScope)
        .onAppear {
            Task { @MainActor in
                // Wait until the popup's focusable controls have joined the
                // focus hierarchy, then move focus off the underlying card.
                await Task.yield()
                if item.resumeOffsetMS > 0 {
                    resumeHasFocus = true
                } else {
                    playHasFocus = true
                }
            }
        }
        .onExitCommand { store.selectedMedia = nil }
    }

    private var metadataLine: String? {
        var values = [item.mediaType?.uppercased(), item.date, item.contentRating]
        if let rating = item.communityRating, rating > 0 {
            values.append(String(format: "★ %.1f", rating))
        }
        if let category = item.category, !category.isEmpty {
            values.append(category)
        }
        return values
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: "  •  ")
            .nilIfEmpty
    }

    private var detailPoster: String? {
        if item.mediaType?.lowercased() == "episode" {
            return item.seasonPoster ?? item.seriesPoster ?? item.poster
        }
        return item.poster ?? item.seriesPoster ?? item.seasonPoster
    }

    private var hasPlayableSource: Bool {
        store.isDemo || item.streamURL?.isEmpty == false || item.nzbURL?.isEmpty == false
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
