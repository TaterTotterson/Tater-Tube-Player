import SwiftUI

struct MediaCardView: View {
    let item: MediaItem

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            ArtworkView(remoteValue: item.poster, demoName: item.demoArtworkName)
                .frame(width: 248, height: 365)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(alignment: .bottom) {
                    if item.visibleProgress > 0 {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Color.white.opacity(0.2)
                                TaterTheme.orange
                                    .frame(width: geometry.size.width * item.visibleProgress)
                            }
                        }
                        .frame(height: 7)
                    }
                }

            VStack(alignment: .leading, spacing: 7) {
                Text(item.title)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if let subtitle = item.subtitle ?? item.date {
                    Text(subtitle)
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundStyle(TaterTheme.secondaryText)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 70, alignment: .topLeading)
        }
        .frame(width: 248, height: 452, alignment: .topLeading)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct WideMediaCardView: View {
    let item: MediaItem

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ArtworkView(remoteValue: item.wideShelfArtwork, demoName: item.wideDemoArtworkName)
                .frame(width: 340, height: 202)

            LinearGradient(
                colors: [Color.black.opacity(0.08), Color.black.opacity(0.38), Color.black.opacity(0.92)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(eyebrow)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(TaterTheme.orangeBright)
                    .lineLimit(1)

                Text(item.title)
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if let subtitle = subtitleText {
                    Text(subtitle)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, item.visibleProgress > 0 ? 19 : 17)

            if item.visibleProgress > 0 {
                GeometryReader { geometry in
                    VStack {
                        Spacer()
                        ZStack(alignment: .leading) {
                            Color.white.opacity(0.24)
                            TaterTheme.orange
                                .frame(width: geometry.size.width * item.visibleProgress)
                        }
                        .frame(height: 6)
                    }
                }
            }
        }
        .frame(width: 340, height: 202)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var eyebrow: String {
        let kind = (item.mediaType ?? item.type ?? "VIDEO").uppercased()
        guard let date = item.date, !date.isEmpty else { return kind }
        return "\(kind)  •  \(date)"
    }

    private var subtitleText: String? {
        if item.recentItems.count == 1 {
            return item.recentItems.first?.title
        }
        if item.recentItems.count > 1 {
            return "\(item.recentItems.count) recently added episodes"
        }
        return item.subtitle ?? item.durationDisplay ?? item.category
    }
}

struct LiveChannelCardView: View {
    @EnvironmentObject private var store: PlayerStore

    let channel: LiveChannel
    let guide: TubeTVGuide?

    private var elapsed: Double {
        guide?.elapsedSeconds() ?? 0
    }

    private var displayedPrograms: [LiveProgram] {
        guard guide != nil else {
            return [channel.now, channel.next].compactMap { $0 }
        }
        return channel.displayedPrograms(elapsed: elapsed)
    }

    private var currentProgram: LiveProgram? {
        displayedPrograms.first ?? channel.now
    }

    private var nextProgram: LiveProgram? {
        displayedPrograms.dropFirst().first ?? channel.next
    }

    private var shelfArtwork: String? {
        if let currentProgram,
           let artwork = store.guideArtworkURL(for: currentProgram),
           !artwork.isEmpty {
            return artwork
        }
        if let nextProgram,
           let artwork = store.guideArtworkURL(for: nextProgram),
           !artwork.isEmpty {
            return artwork
        }
        return nil
    }

    private var shelfDemoArtworkName: String? {
        currentProgram?.wideDemoArtworkName ?? nextProgram?.wideDemoArtworkName
    }

    private var visibleProgress: CGFloat {
        guard guide != nil, let currentProgram else { return channel.visibleProgress }
        return CGFloat(currentProgram.progress(at: elapsed))
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ArtworkView(
                remoteValue: shelfArtwork,
                demoName: shelfDemoArtworkName
            )
            .frame(width: 340, height: 202)

            LinearGradient(
                colors: [Color.black.opacity(0.08), Color.black.opacity(0.4), Color.black.opacity(0.93)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(channel.number.isEmpty ? "LIVE" : "CH \(channel.number)  •  LIVE")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(TaterTheme.orangeBright)

                Text(currentProgram?.title ?? channel.title)
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(nextProgram.map { "Up next: \($0.title)" } ?? channel.title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, visibleProgress > 0 ? 19 : 17)

            if visibleProgress > 0 {
                GeometryReader { geometry in
                    VStack {
                        Spacer()
                        ZStack(alignment: .leading) {
                            Color.white.opacity(0.24)
                            TaterTheme.orange
                                .frame(width: geometry.size.width * visibleProgress)
                        }
                        .frame(height: 6)
                    }
                }
            }
        }
        .frame(width: 340, height: 202)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private extension MediaItem {
    var wideShelfArtwork: String? {
        firstArtwork(backdrop, localBackdropVariant, episodeStill, poster, seasonPoster, seriesPoster)
    }

    var wideDemoArtworkName: String? {
        guard let demoArtworkName else { return nil }
        return demoArtworkName.hasSuffix("-poster")
            ? String(demoArtworkName.dropLast("-poster".count))
            : demoArtworkName
    }

    var visibleProgress: CGFloat {
        let measured = CGFloat(min(max((progressPercent ?? 0) / 100, 0), 1))
        if measured > 0 { return measured }

        // A growing Discover stream may not expose its final runtime yet. Its
        // saved offset still tells us it is resumable, so show a small started
        // marker without pretending that we know an exact percentage.
        return resumeOffsetMS > 0 ? 0.10 : 0
    }

    var localBackdropVariant: String? {
        localWideArtworkVariant(from: poster)
    }
}

private extension LiveProgram {
    var wideShelfArtwork: String? {
        firstArtwork(backdrop, localWideArtworkVariant(from: poster), episodeStill, poster, seasonPoster, seriesPoster)
    }

    var wideDemoArtworkName: String? {
        guard let demoArtworkName else { return nil }
        return demoArtworkName.hasSuffix("-poster")
            ? String(demoArtworkName.dropLast("-poster".count))
            : demoArtworkName
    }
}

private extension LiveChannel {
    var visibleProgress: CGFloat {
        CGFloat(min(max((now?.progressPercent ?? 0) / 100, 0), 1))
    }
}

private func firstArtwork(_ values: String?...) -> String? {
    values.first { $0?.isEmpty == false } ?? nil
}

private func localWideArtworkVariant(from value: String?) -> String? {
    guard let value,
          var components = URLComponents(string: value),
          components.path.contains("/api/v1/player/artwork/local")
    else { return nil }

    var query = components.queryItems ?? []
    query.removeAll { $0.name == "kind" || $0.name == "thumbnail" }
    query.append(URLQueryItem(name: "kind", value: "backdrop"))
    query.append(URLQueryItem(name: "thumbnail", value: "wide"))
    components.queryItems = query
    return components.url?.absoluteString
}
