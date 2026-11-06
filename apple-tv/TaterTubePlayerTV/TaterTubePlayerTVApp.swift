import SwiftUI

@main
struct TaterTubePlayerTVApp: App {
    @StateObject private var playerStore = PlayerStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(playerStore)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    Task { await playerStore.handleDeepLink(url) }
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .background else { return }
                    Task { await playerStore.stopPlaybackForAppBackground() }
                }
        }
    }
}
