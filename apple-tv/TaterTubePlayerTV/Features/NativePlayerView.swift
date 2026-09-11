import AVKit
import SwiftUI

struct NativePlayerScreen: View {
    @EnvironmentObject private var store: PlayerStore

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player = store.playback.player {
                AVPlayerControllerView(player: player, plan: store.playback.plan)
                    .ignoresSafeArea()
            }

            if store.playback.state == .preparing {
                VStack(spacing: 24) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(TaterTheme.orange)
                    Text(store.playback.statusMessage)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                }
                .padding(.horizontal, 42)
                .padding(.vertical, 30)
                .taterGlass(cornerRadius: 28)
            }

            if case .failed(let message) = store.playback.state {
                VStack(spacing: 24) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 62))
                        .foregroundStyle(TaterTheme.orange)
                    Text("Playback stopped")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    Text(message)
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                        .foregroundStyle(TaterTheme.secondaryText)
                        .multilineTextAlignment(.center)
                    Button("Back") { Task { await store.stopPlayback() } }
                        .buttonStyle(.borderedProminent)
                        .tint(TaterTheme.orange)
                }
                .padding(48)
                .frame(maxWidth: 760)
                .taterGlass(cornerRadius: 32)
            }
        }
        .onExitCommand { Task { await store.stopPlayback() } }
        .onChange(of: store.playback.shouldDismiss) { _, shouldDismiss in
            guard shouldDismiss else { return }
            Task { await store.stopPlayback() }
        }
    }
}

private struct AVPlayerControllerView: UIViewControllerRepresentable {
    let player: AVPlayer
    let plan: PlaybackPlan?

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.requiresLinearPlayback = false
        controller.customInfoViewControllers = [PlaybackDetailsController(plan: plan)]
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        controller.player = player
        if let details = controller.customInfoViewControllers.first as? PlaybackDetailsController {
            details.update(plan: plan)
        }
    }
}

private final class PlaybackDetailsController: UIHostingController<PlaybackDetailsPanel> {
    init(plan: PlaybackPlan?) {
        super.init(rootView: PlaybackDetailsPanel(plan: plan))
        title = "Playback"
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(plan: PlaybackPlan?) {
        rootView = PlaybackDetailsPanel(plan: plan)
    }
}

private struct PlaybackDetailsPanel: View {
    let plan: PlaybackPlan?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(plan?.qualityLabel ?? "Preparing playback", systemImage: "waveform.path")
                .font(.system(size: 29, weight: .bold, design: .rounded))
                .foregroundStyle(TaterTheme.orange)

            if let resolution = plan?.resolutionLabel, !resolution.isEmpty {
                Label(resolution, systemImage: "rectangle.inset.filled")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
            }

            if let container = plan?.outputContainer, !container.isEmpty {
                Label(containerLabel(container), systemImage: "shippingbox.fill")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(TaterTheme.secondaryText)
            }

            if let reason = plan?.reason, !reason.isEmpty {
                Text(reason)
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundStyle(TaterTheme.secondaryText)
            }
        }
        .padding(36)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func containerLabel(_ value: String) -> String {
        value.lowercased() == "mpegts" ? "MPEG-TS stream" : "\(value.uppercased()) stream"
    }
}
