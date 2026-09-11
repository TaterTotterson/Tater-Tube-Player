import SwiftUI

struct MediaDetailView: View {
    @EnvironmentObject private var store: PlayerStore
    @Environment(\.dismiss) private var dismiss

    let item: MediaItem

    var body: some View {
        ZStack {
            ArtworkView(remoteValue: item.backdrop ?? item.poster, demoName: item.demoArtworkName)
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.64))
                .blur(radius: 8)

            HStack(spacing: 42) {
                ArtworkView(remoteValue: item.poster, demoName: item.demoArtworkName)
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

                    if let summary = item.summary, !summary.isEmpty {
                        Text(summary)
                            .font(.system(size: 25, weight: .regular, design: .rounded))
                            .foregroundStyle(TaterTheme.secondaryText)
                            .lineLimit(5)
                    }

                    Spacer(minLength: 10)

                    HStack(spacing: 20) {
                        if item.resumeOffsetMS > 0 {
                            Button {
                                Task { await store.play(item, resume: true) }
                            } label: {
                                Label("Resume", systemImage: "play.fill")
                            }
                        }

                        Button {
                            Task { await store.play(item, resume: false) }
                        } label: {
                            Label(item.resumeOffsetMS > 0 ? "Start Over" : "Play", systemImage: "play")
                        }
                        .disabled(item.streamURL?.isEmpty != false || store.isDemo)

                        if item.resumeOffsetMS > 0 {
                            Button(role: .destructive) {
                                Task { await store.clearProgress(for: item) }
                            } label: {
                                Image(systemName: "arrow.counterclockwise")
                                    .accessibilityLabel("Clear watch progress")
                            }
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
        [item.mediaType?.uppercased(), item.date]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: "  •  ")
            .nilIfEmpty
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
