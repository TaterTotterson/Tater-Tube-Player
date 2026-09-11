import SwiftUI

struct MediaCardView: View {
    let item: MediaItem

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            ArtworkView(remoteValue: item.poster, demoName: item.demoArtworkName)
                .frame(width: 248, height: 365)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(alignment: .bottom) {
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
        .frame(width: 248, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct LiveChannelCardView: View {
    let channel: LiveChannel

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            ZStack {
                ArtworkView(remoteValue: channel.logoURL, demoName: nil, contentMode: .fit)
                    .padding(22)
            }
            .frame(width: 304, height: 178)
            .background(Color.white.opacity(0.035))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text(channel.number.isEmpty ? channel.title : "CH \(channel.number)  ·  \(channel.title)")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)

            if let now = channel.now {
                Text(now.title)
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(TaterTheme.secondaryText)
                    .lineLimit(1)
            }
        }
        .frame(width: 304, alignment: .leading)
    }
}
