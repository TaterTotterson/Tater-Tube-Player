import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: PlayerStore
    @Binding var selectedTab: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            BundledImageView(name: "tater-tube-logo-leaning-transparent")
                .scaledToFit()
                .frame(width: 520, alignment: .leading)

            if store.isDemo {
                Text("Demo Mode")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
            } else {
                Text(store.home?.serverName ?? "Tater Tube Server")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text(store.serverURL?.absoluteString ?? "")
                    .font(.system(size: 23, weight: .medium, design: .rounded))
                    .foregroundStyle(TaterTheme.secondaryText)
            }

            HStack(spacing: 22) {
                if !store.isDemo {
                    TaterActionButton(
                        prominent: true,
                        action: { Task { await store.refreshHome(showActivity: true) } }
                    ) {
                        Text("Refresh Now")
                    }
                }
                TaterActionButton(action: { store.disconnect() }) {
                    Text(store.isDemo ? "Leave Demo" : "Disconnect")
                }
            }
        }
        .padding(58)
        .frame(width: 940, alignment: .leading)
        .taterGlass(cornerRadius: 36)
        .overlay(alignment: .topTrailing) {
            if store.isRefreshing {
                ProgressView().tint(TaterTheme.orange).padding(36)
            }
        }
        .onExitCommand { selectedTab = 0 }
    }
}
