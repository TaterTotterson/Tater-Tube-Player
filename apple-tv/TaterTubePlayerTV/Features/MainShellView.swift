import SwiftUI

struct MainShellView: View {
    @EnvironmentObject private var store: PlayerStore
    @State private var selectedTab = ProcessInfo.processInfo.arguments.contains("--picks")
        ? 4
        : (ProcessInfo.processInfo.arguments.contains("--discover")
            ? 3
            : (ProcessInfo.processInfo.arguments.contains("--live")
                ? 2
                : (ProcessInfo.processInfo.arguments.contains("--library") ? 1 : 0)))

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            LibraryView(selectedTab: $selectedTab)
                .tabItem { Label("Library", systemImage: "rectangle.stack.fill") }
                .tag(1)

            if store.home?.capabilities.tubeTV == true {
                LiveTVView()
                .tabItem { Label("Live TV", systemImage: "tv.fill") }
                .tag(2)
            }

            if store.home?.capabilities.newznab == true {
                DiscoveryView()
                .tabItem { Label("Discover", systemImage: "sparkles.tv.fill") }
                .tag(3)
            }

            if store.home?.capabilities.taterLink == true {
                TaterPicksView()
                .tabItem { Label("Picks", systemImage: "wand.and.stars") }
                .tag(4)
            }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(5)
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
        .alert("Tater Tube Player", isPresented: storeErrorIsPresented) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "Something went wrong.")
        }
    }

    private var storeErrorIsPresented: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )
    }
}
