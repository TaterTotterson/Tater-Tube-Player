import AVKit
import SwiftUI

struct NativePlayerScreen: View {
    @EnvironmentObject private var store: PlayerStore

    var body: some View {
        NativePlayerContent(playback: store.playback)
            .environmentObject(store)
    }
}

private struct NativePlayerContent: View {
    private enum PlayerFocus: Hashable {
        case surface
        case audio
        case subtitles
    }

    @EnvironmentObject private var store: PlayerStore
    @ObservedObject var playback: PlaybackCoordinator

    @FocusState private var focusedControl: PlayerFocus?
    @State private var controlsVisible = true
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var channelLogoImage: UIImage?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player = playback.player {
                PlayerLayerView(
                    player: player,
                    channelLogoImage: channelLogoImage,
                    channelLogoPosition: playback.currentItem?.channelLogoPosition,
                    showsChannelLogo: shouldShowChannelLogo
                )
                    .ignoresSafeArea()
            }

            Color.clear
                .contentShape(Rectangle())
                .focusable()
                .focusEffectDisabled()
                .focused($focusedControl, equals: .surface)
                .onTapGesture { toggleControls() }

            if playback.state == .preparing {
                loadingPanel
            }

            if case .failed(let message) = playback.state {
                failurePanel(message: message)
            }

            if controlsVisible,
               playback.state == .playing || playback.state == .preparing {
                TaterPlaybackOverlay(
                    playback: playback,
                    focusedControl: $focusedControl,
                    audioFocus: .audio,
                    subtitleFocus: .subtitles,
                    onAudio: {
                        revealControls()
                        Task { await playback.cycleAudioTrack() }
                    },
                    onSubtitles: {
                        revealControls()
                        playback.cycleSubtitleTrack()
                    }
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeOut(duration: 0.22), value: controlsVisible)
        .onAppear {
            focusedControl = .surface
            revealControls()
        }
        .onDisappear { hideControlsTask?.cancel() }
        .task(id: channelLogoURLToLoad) {
            channelLogoImage = nil
            guard let channelLogoURLToLoad else { return }
            if let cached = ArtworkMemoryCache.shared.image(for: channelLogoURLToLoad) {
                channelLogoImage = cached
                return
            }
            if let data = try? await store.artworkData(for: channelLogoURLToLoad),
               !Task.isCancelled,
               let loaded = UIImage(data: data) {
                ArtworkMemoryCache.shared.insert(loaded, for: channelLogoURLToLoad)
                channelLogoImage = loaded
            }
        }
        .onPlayPauseCommand {
            playback.togglePlayPause()
            revealControls()
        }
        .onMoveCommand { direction in
            handleMove(direction)
        }
        .onExitCommand { Task { await store.stopPlayback() } }
        .onChange(of: focusedControl) { _, focus in
            if focus == .audio || focus == .subtitles {
                controlsVisible = true
                hideControlsTask?.cancel()
            } else {
                scheduleControlsHide()
            }
        }
        .onChange(of: playback.isPaused) { _, paused in
            if paused { revealControls(autoHide: false) }
            else { scheduleControlsHide() }
        }
        .onChange(of: playback.shouldDismiss) { _, shouldDismiss in
            guard shouldDismiss else { return }
            Task { await store.stopPlayback() }
        }
    }

    private var loadingPanel: some View {
        VStack(spacing: 24) {
            ProgressView()
                .controlSize(.large)
                .tint(TaterTheme.orange)
            Text(playback.isChangingAudioTrack ? "Changing audio track…" : playback.statusMessage)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
        }
        .padding(.horizontal, 42)
        .padding(.vertical, 30)
        .taterGlass(cornerRadius: 28)
    }

    private var channelLogoURLToLoad: String? {
        guard let item = playback.currentItem,
              item.isLiveChannel,
              item.channelLogoOverlayEnabled == true,
              let logoURL = item.channelLogoURL,
              !logoURL.isEmpty
        else { return nil }
        return logoURL
    }

    private var shouldShowChannelLogo: Bool {
        guard channelLogoURLToLoad != nil,
              let item = playback.currentItem
        else { return false }
        return !currentChannelProgramIsInterstitial(item)
    }

    private func currentChannelProgramIsInterstitial(_ item: MediaItem) -> Bool {
        guard let number = item.channelNumber,
              let guide = store.liveGuide,
              let channel = guide.channels.first(where: { $0.number == number })
        else { return false }
        let elapsed = guide.elapsedSeconds()
        return channel.schedule.first(where: {
            $0.start <= elapsed && elapsed < $0.end
        })?.isInterstitial == true
    }

    private func failurePanel(message: String) -> some View {
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
            TaterActionButton(
                prominent: true,
                action: { Task { await store.stopPlayback() } }
            ) {
                Text("Back")
            }
        }
        .padding(48)
        .frame(maxWidth: 760)
        .taterGlass(cornerRadius: 32)
    }

    private func handleMove(_ direction: MoveCommandDirection) {
        controlsVisible = true
        if focusedControl == .surface {
            switch direction {
            case .left:
                playback.seek(by: -10)
            case .right:
                playback.seek(by: 10)
            case .down:
                if playback.hasMultipleAudioTracks {
                    focusedControl = .audio
                } else if playback.hasSubtitles {
                    focusedControl = .subtitles
                }
            default:
                break
            }
        } else {
            switch (focusedControl, direction) {
            case (.audio, .right) where playback.hasSubtitles:
                focusedControl = .subtitles
            case (.subtitles, .left) where playback.hasMultipleAudioTracks:
                focusedControl = .audio
            case (_, .up):
                focusedControl = .surface
            default:
                break
            }
        }
        revealControls()
    }

    private func toggleControls() {
        controlsVisible.toggle()
        if !controlsVisible {
            focusedControl = .surface
            hideControlsTask?.cancel()
        } else {
            scheduleControlsHide()
        }
    }

    private func revealControls(autoHide: Bool = true) {
        controlsVisible = true
        hideControlsTask?.cancel()
        if autoHide { scheduleControlsHide() }
    }

    private func scheduleControlsHide() {
        hideControlsTask?.cancel()
        guard !playback.isPaused, focusedControl == .surface else { return }
        hideControlsTask = Task {
            try? await Task.sleep(for: .seconds(4.5))
            guard !Task.isCancelled, !playback.isPaused, focusedControl == .surface else { return }
            controlsVisible = false
        }
    }
}

private struct TaterPlaybackOverlay<Focus: Hashable>: View {
    @ObservedObject var playback: PlaybackCoordinator
    var focusedControl: FocusState<Focus?>.Binding
    let audioFocus: Focus
    let subtitleFocus: Focus
    let onAudio: () -> Void
    let onSubtitles: () -> Void

    private var item: MediaItem? { playback.currentItem }
    private var plan: PlaybackPlan? { playback.plan }

    var body: some View {
        VStack {
            Spacer()

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item?.title ?? "Now Playing")
                            .font(.system(size: 31, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        HStack(spacing: 10) {
                            playbackBadge

                            if let resolution = plan?.resolutionLabel, !resolution.isEmpty {
                                Label(resolution, systemImage: "rectangle.inset.filled")
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.78))
                            }

                            Text(pathDetail)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(TaterTheme.secondaryText)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 20)

                    trackControl(
                        title: playback.audioTrackLabel,
                        icon: "waveform",
                        maxWidth: 360,
                        focus: audioFocus,
                        enabled: playback.hasMultipleAudioTracks && !playback.isChangingAudioTrack,
                        action: onAudio
                    )

                    trackControl(
                        title: playback.subtitleTrackLabel,
                        icon: "captions.bubble.fill",
                        maxWidth: 220,
                        focus: subtitleFocus,
                        enabled: playback.hasSubtitles,
                        action: onSubtitles
                    )
                }

                if let message = playback.playbackControlMessage, !message.isEmpty {
                    Text(message)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(TaterTheme.orangeBright)
                }

                timeline
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 27)
            .taterGlass(cornerRadius: 30)
            .padding(.horizontal, 54)
            .padding(.bottom, 42)
        }
    }

    private func trackControl(
        title: String,
        icon: String,
        maxWidth: CGFloat,
        focus: Focus,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let selected = focusedControl.wrappedValue == focus

        return Label(title, systemImage: icon)
        .font(.system(size: 18, weight: .bold, design: .rounded))
        .lineLimit(1)
        .minimumScaleFactor(0.66)
        .foregroundStyle(selected ? TaterTheme.orangeBright : Color.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: maxWidth)
        .background(
            selected ? Color.black.opacity(0.90) : Color.black.opacity(0.58),
            in: Capsule()
        )
        .overlay {
            Capsule()
                .stroke(
                    selected ? TaterTheme.orangeBright : TaterTheme.orange.opacity(0.62),
                    lineWidth: selected ? 3 : 1.5
                )
        }
        .shadow(
            color: selected ? TaterTheme.orange.opacity(0.38) : .clear,
            radius: selected ? 14 : 0
        )
        .contentShape(Capsule())
        .focusable(enabled)
        .focusEffectDisabled()
        .opacity(enabled ? 1 : 0.48)
        .focused(focusedControl, equals: focus)
        .animation(.easeOut(duration: 0.16), value: selected)
        .onTapGesture {
            guard enabled else { return }
            action()
        }
        .accessibilityAddTraits(.isButton)
    }

    private var playbackBadge: some View {
        Label(processingLabel, systemImage: processingIcon)
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundStyle(processingColor)
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(processingColor.opacity(0.14), in: Capsule())
            .overlay(Capsule().stroke(processingColor.opacity(0.38), lineWidth: 1))
    }

    private var timeline: some View {
        HStack(spacing: 15) {
            Text(item?.isLiveChannel == true ? "LIVE" : format(playback.playbackPositionMS))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(item?.isLiveChannel == true ? TaterTheme.orangeBright : .white)
                .frame(width: 88, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.20))
                    Capsule()
                        .fill(TaterTheme.orange)
                        .frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 7)

            Text(item?.isLiveChannel == true ? "ON AIR" : format(playback.playbackDurationMS))
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(TaterTheme.secondaryText)
                .frame(width: 88, alignment: .trailing)
        }
    }

    private var progress: CGFloat {
        guard playback.playbackDurationMS > 0 else { return item?.isLiveChannel == true ? 1 : 0 }
        return min(1, max(0, CGFloat(playback.playbackPositionMS) / CGFloat(playback.playbackDurationMS)))
    }

    private var processingLabel: String {
        switch plan?.mode.lowercased() {
        case "direct": return "Direct Play"
        case "audio_transcode": return "Audio Transcode"
        case "video_transcode": return "Video Transcode"
        case "full_transcode": return "Full Transcode"
        default: return plan?.qualityLabel ?? "Preparing"
        }
    }

    private var processingIcon: String {
        plan?.mode.lowercased() == "direct" ? "checkmark.circle.fill" : "bolt.horizontal.circle.fill"
    }

    private var processingColor: Color {
        plan?.mode.lowercased() == "direct" ? Color.green : TaterTheme.orangeBright
    }

    private var pathDetail: String {
        guard let plan else { return "PREPARING STREAM" }
        var video = modeLabel(plan.videoMode, fallback: plan.videoCodec)
        if let outputRange = plan.outputVideoRange?.lowercased(), outputRange != "sdr" {
            video += " " + outputRange.replacingOccurrences(of: "_", with: " ").uppercased()
        }
        if let frameRate = plan.outputFrameRate, frameRate > 0 {
            video += " " + String(format: "%.2f FPS", frameRate)
        }
        let audio: String
        if plan.audioMode.lowercased() == "transcode" {
            let codec = (plan.audioCodec?.isEmpty == false ? plan.audioCodec! : "AAC").uppercased()
            let channels: String
            switch plan.outputAudioChannels {
            case 6: channels = " 5.1"
            case 8: channels = " 7.1"
            case 2: channels = " STEREO"
            default: channels = ""
            }
            audio = "TRANSCODE \(codec)\(channels)"
        } else {
            audio = modeLabel(plan.audioMode, fallback: plan.audioCodec)
        }
        return "VIDEO \(video)  •  AUDIO \(audio)"
    }

    private func modeLabel(_ mode: String, fallback: String?) -> String {
        switch mode.lowercased() {
        case "direct", "copy": return "DIRECT"
        case "transcode": return "TRANSCODE"
        default: return (fallback?.isEmpty == false ? fallback! : mode).uppercased()
        }
    }

    private func format(_ milliseconds: Int64) -> String {
        let total = max(0, milliseconds / 1000)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, seconds) }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    let channelLogoImage: UIImage?
    let channelLogoPosition: String?
    let showsChannelLogo: Bool

    func makeUIView(context: Context) -> PlayerSurfaceView {
        let view = PlayerSurfaceView()
        view.update(
            player: player,
            channelLogoImage: channelLogoImage,
            channelLogoPosition: channelLogoPosition,
            showsChannelLogo: showsChannelLogo
        )
        return view
    }

    func updateUIView(_ view: PlayerSurfaceView, context: Context) {
        view.update(
            player: player,
            channelLogoImage: channelLogoImage,
            channelLogoPosition: channelLogoPosition,
            showsChannelLogo: showsChannelLogo
        )
    }
}

private final class PlayerSurfaceView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    private let channelLogoView = UIImageView()
    private var channelLogoPosition = "bottom_right"

    override init(frame: CGRect) {
        super.init(frame: frame)
        channelLogoView.backgroundColor = .clear
        channelLogoView.contentMode = .scaleAspectFit
        channelLogoView.alpha = 0.74
        channelLogoView.isHidden = true
        channelLogoView.isUserInteractionEnabled = false
        channelLogoView.layer.shouldRasterize = true
        channelLogoView.layer.rasterizationScale = UIScreen.main.scale
        addSubview(channelLogoView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(
        player: AVPlayer,
        channelLogoImage: UIImage?,
        channelLogoPosition: String?,
        showsChannelLogo: Bool
    ) {
        if playerLayer.player !== player {
            playerLayer.videoGravity = .resizeAspect
            playerLayer.player = player
        }
        if channelLogoView.image !== channelLogoImage {
            channelLogoView.image = channelLogoImage
        }
        let nextPosition = channelLogoPosition?.lowercased() ?? "bottom_right"
        if self.channelLogoPosition != nextPosition {
            self.channelLogoPosition = nextPosition
            setNeedsLayout()
        }
        let shouldHide = !showsChannelLogo || channelLogoImage == nil
        if channelLogoView.isHidden != shouldHide {
            channelLogoView.isHidden = shouldHide
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Keep the station bug inside a broadcast-style safe area so it remains
        // readable without feeling pinned to the bezel on any selected corner.
        let size = CGSize(width: 132, height: 88)
        let horizontalInset: CGFloat = 64
        let verticalInset: CGFloat = 52
        let x: CGFloat
        let y: CGFloat
        switch channelLogoPosition {
        case "top_left":
            x = horizontalInset
            y = verticalInset
        case "top_right":
            x = bounds.width - horizontalInset - size.width
            y = verticalInset
        case "bottom_left":
            x = horizontalInset
            y = bounds.height - verticalInset - size.height
        default:
            x = bounds.width - horizontalInset - size.width
            y = bounds.height - verticalInset - size.height
        }
        channelLogoView.frame = CGRect(origin: CGPoint(x: x, y: y), size: size)
    }
}
