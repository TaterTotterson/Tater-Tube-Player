import SwiftUI

struct MainShellView: View {
    @EnvironmentObject private var store: PlayerStore

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            LibraryView()
                .tabItem { Label("Library", systemImage: "rectangle.stack.fill") }

            if store.home?.capabilities.tubeTV == true {
                ComingSoonView(
                    icon: "tv.fill",
                    title: "Live TV",
                    message: "The native guide and channel playback are the next parity milestone."
                )
                .tabItem { Label("Live TV", systemImage: "tv.fill") }
            }

            if store.home?.capabilities.newznab == true {
                ComingSoonView(
                    icon: "sparkles.tv.fill",
                    title: "Discover",
                    message: "Discovery search and resumable streaming are coming into this native client next."
                )
                .tabItem { Label("Discover", systemImage: "sparkles.tv.fill") }
            }

            if store.home?.capabilities.taterLink == true {
                ComingSoonView(
                    icon: "wand.and.stars",
                    title: "Tater Picks",
                    message: "Tater's recommendations and spoken group message will use the existing server endpoints."
                )
                .tabItem { Label("Picks", systemImage: "wand.and.stars") }
            }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(TaterTheme.orange)
        .sheet(item: $store.selectedMedia) { item in
            MediaDetailView(item: item)
                .environmentObject(store)
        }
        .fullScreenCover(isPresented: $store.isPlaybackPresented) {
            NativePlayerScreen()
                .environmentObject(store)
        }
    }
}

private struct ComingSoonView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: icon)
                .font(.system(size: 92, weight: .light))
                .foregroundStyle(TaterTheme.orange)
            Text(title)
                .font(.system(size: 52, weight: .bold, design: .rounded))
            Text(message)
                .font(.system(size: 27, weight: .medium, design: .rounded))
                .foregroundStyle(TaterTheme.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 760)
        }
        .padding(64)
        .taterGlass(cornerRadius: 34)
    }
}
