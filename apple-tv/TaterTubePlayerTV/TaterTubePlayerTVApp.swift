import SwiftUI

@main
struct TaterTubePlayerTVApp: App {
    @StateObject private var playerStore = PlayerStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(playerStore)
                .preferredColorScheme(.dark)
        }
    }
}
