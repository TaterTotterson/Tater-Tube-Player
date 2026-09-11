import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: PlayerStore

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
                    Button("Refresh Now") { Task { await store.refreshHome(showActivity: true) } }
                }
                Button(store.isDemo ? "Leave Demo" : "Disconnect", role: .destructive) {
                    store.disconnect()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(TaterTheme.orange)
        }
        .padding(58)
        .frame(width: 940, alignment: .leading)
        .taterGlass(cornerRadius: 36)
        .overlay(alignment: .topTrailing) {
            if store.isRefreshing {
                ProgressView().tint(TaterTheme.orange).padding(36)
            }
        }
    }
}
