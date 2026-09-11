import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: PlayerStore

    var body: some View {
        ZStack {
            TaterBackground()

            switch store.phase {
            case .starting:
                VStack(spacing: 28) {
                    BundledImageView(name: "tater-tube-logo-leaning-transparent")
                        .scaledToFit()
                        .frame(width: 620)
                    ProgressView()
                        .tint(TaterTheme.orange)
                }
            case .pairing:
                PairingView()
            case .ready:
                MainShellView()
            }
        }
        .task { await store.start() }
    }
}

struct TaterBackground: View {
    var body: some View {
        ZStack {
            Color.black
            RadialGradient(
                colors: [TaterTheme.orange.opacity(0.16), .clear],
                center: UnitPoint(x: 0.72, y: 0.12),
                startRadius: 20,
                endRadius: 720
            )
        }
        .ignoresSafeArea()
    }
}
