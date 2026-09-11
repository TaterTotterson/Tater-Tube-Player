import SwiftUI

struct MediaDetailView: View {
    @EnvironmentObject private var store: PlayerStore
    @Environment(\.dismiss) private var dismiss

    let item: MediaItem

    var body: some View {
        ZStack {
            ArtworkView(remoteValue: detailBackdrop, demoName: item.demoArtworkName)
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.64))
                .blur(radius: 8)

            HStack(spacing: 42) {
                ArtworkView(remoteValue: detailPoster, demoName: item.demoArtworkName)
                    .frame(width: 330, height: 490)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                VStack(alignment: .leading, spacing: 22) {
                    Text(item.title)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .lineLimit(2)

                    if let metadata = metadataLine {
                        Text(metadata)
                            .font(.system(size: 23, weight: .bold, design: .rounded))
                            .foregroundStyle(TaterTheme.orange)
                    }

                    if let tagline = item.tagline, !tagline.isEmpty {
                        Text(tagline)
                            .font(.system(size: 25, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.88))
                            .italic()
                            .lineLimit(2)
                    }

                    if let summary = item.summary, !summary.isEmpty {
                        Text(summary)
                            .font(.system(size: 25, weight: .regular, design: .rounded))
                            .foregroundStyle(TaterTheme.secondaryText)
                            .lineLimit(5)
                    }

                    Spacer(minLength: 10)

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
                            Button {
                                Task { await store.play(item, resume: true) }
                            } label: {
                                Label("Resume", systemImage: "play.fill")
                            }
                            .disabled(!hasPlayableSource || store.isDemo || store.isPreparingDiscovery)
                        }

                        Button {
                            Task { await store.play(item, resume: false) }
                        } label: {
                            Label(item.resumeOffsetMS > 0 ? "Start Over" : "Play", systemImage: "play")
                        }
                        .disabled(!hasPlayableSource || store.isDemo || store.isPreparingDiscovery)

                        if item.resumeOffsetMS > 0 {
                            Button(role: .destructive) {
                                Task { await store.clearProgress(for: item) }
                            } label: {
                                Image(systemName: "arrow.counterclockwise")
                                    .accessibilityLabel("Clear watch progress")
                            }
                            .disabled(store.isDemo || store.isPreparingDiscovery)
                        }

                        Button("Close") { dismiss() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TaterTheme.orange)
                }
                .frame(maxWidth: 760, minHeight: 490, alignment: .topLeading)
            }
            .padding(44)
            .taterGlass(cornerRadius: 34)
            .frame(maxWidth: 1240)
        }
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

    private var detailBackdrop: String? {
        item.backdrop ?? item.episodeStill ?? item.seasonPoster ?? item.seriesPoster ?? item.poster
    }

    private var hasPlayableSource: Bool {
        item.streamURL?.isEmpty == false || item.nzbURL?.isEmpty == false
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
