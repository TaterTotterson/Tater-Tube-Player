import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: PlayerStore

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 54) {
                hero

                if let items = store.home?.continueWatching, !items.isEmpty {
                    MediaShelf(title: "Continue Watching", items: items)
                }

                if let channels = store.home?.liveChannels, !channels.isEmpty {
                    liveShelf(channels)
                }

                if let items = store.home?.recentlyAdded, !items.isEmpty {
                    MediaShelf(title: "Recently Added", items: items)
                }
            }
            .padding(.horizontal, 78)
            .padding(.top, 42)
            .padding(.bottom, 110)
        }
        .refreshable { await store.refreshHome() }
    }

    private var hero: some View {
        HStack(spacing: 54) {
            VStack(alignment: .leading, spacing: 18) {
                Text(store.home?.hero?.eyebrow ?? greeting)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .tracking(2.5)
                    .foregroundStyle(TaterTheme.orange)

                Text(store.home?.hero?.message ?? "Everything good, right where you left it.")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                HStack(spacing: 12) {
                    Circle()
                        .fill(store.isDemo ? Color.yellow : Color.green)
                        .frame(width: 11, height: 11)
                    Text(store.isDemo ? "DEMO MODE" : "\(store.home?.serverName ?? "Tater Tube Server") ONLINE")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(TaterTheme.secondaryText)
                }
            }

            Spacer(minLength: 20)

            BundledImageView(name: "tater-hero-remote")
                .scaledToFit()
                .frame(width: 300, height: 260)
        }
        .padding(.horizontal, 55)
        .padding(.vertical, 35)
        .frame(maxWidth: .infinity, minHeight: 320)
        .taterGlass(cornerRadius: 36)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "GOOD MORNING" }
        if hour < 18 { return "GOOD AFTERNOON" }
        return "GOOD EVENING"
    }

    private func liveShelf(_ channels: [LiveChannel]) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Live on Tater Tube")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 28) {
                    ForEach(channels) { channel in
                        Button {
                            // Live guide playback is implemented in the guide milestone.
                        } label: { LiveChannelCardView(channel: channel) }
                            .buttonStyle(.card)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
            .contentMargins(.horizontal, -18, for: .scrollContent)
        }
    }
}

struct MediaShelf: View {
    @EnvironmentObject private var store: PlayerStore

    let title: String
    let items: [MediaItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(title)
                .font(.system(size: 34, weight: .bold, design: .rounded))

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 28) {
                    ForEach(items) { item in
                        Button {
                            store.openDetails(for: item)
                        } label: { MediaCardView(item: item) }
                            .buttonStyle(.card)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
            .contentMargins(.horizontal, -18, for: .scrollContent)
        }
    }
}
