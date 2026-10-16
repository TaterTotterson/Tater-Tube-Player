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
        case seek
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
               (playback.state == .playing || playback.state == .preparing) {
                TaterPlaybackOverlay(
                    playback: playback,
                    focusedControl: $focusedControl,
                    audioFocus: .audio,
                    subtitleFocus: .subtitles,
                    seekFocus: .seek,
                    onAudio: {
                        revealControls()
                        Task { await playback.cycleAudioTrack() }
                    },
                    onSubtitles: {
                        revealControls()
                        playback.cycleSubtitleTrack()
                    },
                    seekFocused: focusedControl == .seek
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeOut(duration: 0.22), value: controlsVisible)
        .onAppear {
            focusedControl = .surface
            revealControls(preferTrackControl: true)
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
        .onExitCommand {
            if controlsVisible,
               playback.state == .playing || playback.state == .preparing {
                hideControls()
            } else {
                Task { await store.stopPlayback() }
            }
        }
        .onChange(of: focusedControl) { _, _ in
            if controlsVisible { scheduleControlsHide() }
        }
        .onChange(of: playback.plan) { _, _ in
            guard controlsVisible, focusedControl == .surface else { return }
            selectInitialControl()
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
        if focusedControl == .surface || focusedControl == .seek {
            switch direction {
            case .left:
                playback.seek(by: -10)
            case .right:
                playback.seek(by: 10)
            case .down where focusedControl == .surface:
                if playback.hasMultipleAudioTracks {
                    focusedControl = .audio
                } else if playback.hasSubtitles {
                    focusedControl = .subtitles
                } else {
                    requestFocus(.seek)
                }
            case .up where focusedControl == .seek:
                selectInitialControl()
            default:
                break
            }
        } else {
            switch (focusedControl, direction) {
            case (.audio, .right) where playback.hasSubtitles:
                focusedControl = .subtitles
            case (.subtitles, .left) where playback.hasMultipleAudioTracks:
                focusedControl = .audio
            case (.audio, .down), (.subtitles, .down):
                requestFocus(.seek)
            default:
                break
            }
        }
        revealControls()
    }

    private func toggleControls() {
        controlsVisible.toggle()
        if !controlsVisible {
            hideControls()
        } else {
            selectInitialControl()
            scheduleControlsHide()
        }
    }

    private func revealControls(autoHide: Bool = true, preferTrackControl: Bool = false) {
        let wasHidden = !controlsVisible
        controlsVisible = true
        hideControlsTask?.cancel()
        if wasHidden || preferTrackControl { selectInitialControl() }
        if autoHide { scheduleControlsHide() }
    }

    private func selectInitialControl() {
        if playback.hasMultipleAudioTracks {
            focusedControl = .audio
        } else if playback.hasSubtitles {
            focusedControl = .subtitles
        } else {
            focusedControl = .surface
        }
    }

    private func requestFocus(_ control: PlayerFocus) {
        // Directional commands arrive while tvOS is still resolving its native
        // focus update. Apply our explicit destination on the next main-loop turn
        // so the system cannot restore the previously focused control afterward.
        DispatchQueue.main.async {
            focusedControl = control
        }
    }

    private func hideControls() {
        controlsVisible = false
        focusedControl = .surface
        hideControlsTask?.cancel()
    }

    private func scheduleControlsHide() {
        hideControlsTask?.cancel()
        guard !playback.isPaused else { return }
        hideControlsTask = Task {
            try? await Task.sleep(for: .seconds(4.5))
            guard !Task.isCancelled, !playback.isPaused else { return }
            hideControls()
        }
    }
}

private struct TaterPlaybackOverlay<Focus: Hashable>: View {
    @ObservedObject var playback: PlaybackCoordinator
    var focusedControl: FocusState<Focus?>.Binding
    let audioFocus: Focus
    let subtitleFocus: Focus
    let seekFocus: Focus
    let onAudio: () -> Void
    let onSubtitles: () -> Void
    let seekFocused: Bool

    private var item: MediaItem? { playback.currentItem }
    private var plan: PlaybackPlan? { playback.plan }
    private var processing: PlaybackProcessingInfo? { playback.processingInfo }

    var body: some View {
        VStack {
            Spacer()

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 18) {
                    Text(item?.title ?? "Now Playing")
                        .font(.system(size: 31, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

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

                processingBadges

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

    private var processingBadges: some View {
        HStack(spacing: 10) {
            if let label = resolutionLabel {
                PlaybackProcessingBadge(label: label, style: .resolution)
            }
            PlaybackProcessingBadge(label: videoProcessingLabel, style: videoBadgeStyle)
            if let label = upscalingLabel {
                PlaybackProcessingBadge(label: label, systemImage: "sparkles", style: .upscaling)
            }
            PlaybackProcessingBadge(label: audioProcessingLabel, systemImage: "waveform", style: .audio)
        }
    }

    private var timeline: some View {
        Button(action: {}) {
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
        .buttonStyle(.plain)
        .padding(.horizontal, seekFocused ? 16 : 0)
        .padding(.vertical, seekFocused ? 12 : 0)
        .background(
            seekFocused ? Color.black.opacity(0.72) : Color.clear,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(seekFocused ? TaterTheme.orangeBright : Color.clear, lineWidth: 2.5)
        }
        .shadow(color: seekFocused ? TaterTheme.orange.opacity(0.42) : .clear, radius: 14)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .focusEffectDisabled()
        .focused(focusedControl, equals: seekFocus)
        .animation(.easeOut(duration: 0.15), value: seekFocused)
        .accessibilityLabel("Seek")
        .accessibilityHint("Press left or right to move through the video")
    }

    private var progress: CGFloat {
        guard playback.playbackDurationMS > 0 else { return item?.isLiveChannel == true ? 1 : 0 }
        return min(1, max(0, CGFloat(playback.playbackPositionMS) / CGFloat(playback.playbackDurationMS)))
    }

    private var resolutionLabel: String? {
        if let processing,
           let source = formatResolution(width: processing.sourceWidth, height: processing.sourceHeight) {
            if let output = formatResolution(width: processing.outputWidth, height: processing.outputHeight),
               processing.videoMode?.lowercased() == "transcode" {
                return "\(source) → \(output)"
            }
            return source
        }
        return plan?.resolutionLabel?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    private var videoProcessingLabel: String {
        let mode = processing?.videoMode?.lowercased() ?? plan?.videoMode.lowercased() ?? "preparing"
        switch mode {
        case "direct", "copy":
            return "VIDEO · DIRECT"
        case "transcode":
            if processing?.hardwareActive == true {
                return "HW \(hardwareLabel(processing?.hardwareAcceleration))"
            }
            if processing != nil { return "SW TRANSCODE" }
            return "VIDEO · TRANSCODE"
        default:
            return "VIDEO · \(mode.uppercased())"
        }
    }

    private var videoBadgeStyle: PlaybackProcessingBadge.Style {
        let mode = processing?.videoMode?.lowercased() ?? plan?.videoMode.lowercased()
        return mode == "direct" || mode == "copy" || processing?.hardwareActive == true
            ? .hardware
            : .software
    }

    private var upscalingLabel: String? {
        if let processing, processing.upscalingActive {
            let method = processing.upscalingMethod?.lowercased() ?? ""
            let requested = processing.upscalingRequested?.lowercased() ?? ""
            if method == "ai" {
                return "AI · \(upscalerModelLabel(processing.upscalingModel))"
            }
            let scaler = method == "spline36" ? "Spline36" : method.capitalized
            if requested == "ai" || requested == "auto" {
                return "AI FALLBACK · \(scaler.nilIfEmpty ?? "Spline36")"
            }
            return "UPSCALE · \(scaler.nilIfEmpty ?? "Spline36")"
        }

        guard let plan,
              let components = URLComponents(string: plan.streamURL),
              let scaler = components.queryItems?.first(where: { $0.name == "tater_scaler" })?.value?.lowercased(),
              !scaler.isEmpty
        else { return nil }
        if scaler == "ai" || scaler == "auto" {
            let model = components.queryItems?.first(where: { $0.name == "tater_ai_model" })?.value
            return "AI · \(upscalerModelLabel(model))"
        }
        return "UPSCALE · \(scaler == "spline36" ? "Spline36" : scaler.capitalized)"
    }

    private var audioProcessingLabel: String {
        guard let plan else { return "AUDIO · PREPARING" }
        let mode = processing?.audioMode?.lowercased() ?? plan.audioMode.lowercased()
        let selectedTrack = plan.source.audioTracks?.first { $0.index == plan.selectedAudioTrack }
        let sourceCodec = codecLabel(selectedTrack?.codec ?? plan.source.audioCodec)
        let sourceChannels = channelLabel(selectedTrack?.channels ?? plan.source.audioChannels)
        let outputCodec = codecLabel(processing?.audioCodec ?? plan.audioCodec)
        let outputChannels = channelLabel(processing?.audioChannels ?? plan.outputAudioChannels)
        let source = [sourceCodec, sourceChannels].compactMap { $0 }.joined(separator: " ")
        let output = [outputCodec, outputChannels].compactMap { $0 }.joined(separator: " ")

        switch mode {
        case "transcode":
            if !source.isEmpty, !output.isEmpty, source != output {
                return "AUDIO · \(source) → \(output)"
            }
            return "AUDIO · TRANSCODE\(output.isEmpty ? "" : " · \(output)")"
        case "bitstream", "passthrough":
            return "AUDIO · BITSTREAM\(source.isEmpty ? "" : " · \(source)")"
        case "none":
            return "AUDIO · NONE"
        default:
            return "AUDIO · DIRECT\(source.isEmpty ? "" : " · \(source)")"
        }
    }

    private func formatResolution(width: Int?, height: Int?) -> String? {
        guard let height, height > 0 else { return nil }
        if height >= 2160 || (width ?? 0) >= 3840 { return "4K" }
        if height >= 1440 { return "1440p" }
        if height >= 1080 { return "1080p" }
        if height >= 720 { return "720p" }
        return "\(height)p"
    }

    private func hardwareLabel(_ value: String?) -> String {
        switch value?.lowercased() {
        case "nvenc", "cuda": return "NVENC"
        case "qsv", "quicksync", "quick_sync": return "QUICK SYNC"
        case "videotoolbox": return "VIDEOTOOLBOX"
        case "vaapi": return "VAAPI"
        case "v4l2m2m": return "V4L2"
        case let value?: return value.uppercased()
        case nil: return "TRANSCODE"
        }
    }

    private func upscalerModelLabel(_ value: String?) -> String {
        switch value?.lowercased() {
        case "fsrcnnx-8": return "FSRCNNX Fast"
        case "fsrcnnx-16": return "FSRCNNX Quality"
        case "anime4k-cnn-m": return "Anime4K Balanced"
        case "anime4k-cnn-l": return "Anime4K Quality"
        case "artcnn-c4f16": return "ArtCNN Balanced"
        case "artcnn-c4f16-ds": return "ArtCNN Restore"
        case "artcnn-c4f32": return "ArtCNN Quality"
        case let value?: return value.replacingOccurrences(of: "-", with: " ").capitalized
        case nil: return "AI Upscaling"
        }
    }

    private func codecLabel(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !value.isEmpty
        else { return nil }
        switch value {
        case "ac3": return "AC-3"
        case "eac3", "e-ac-3": return "E-AC-3"
        case "truehd": return "TRUEHD"
        case "dts_hd_ma", "dts-hd-ma": return "DTS-HD MA"
        case "dts_hd", "dts-hd": return "DTS-HD"
        case "pcm_s16le", "pcm_s24le", "pcm": return "PCM"
        default: return value.uppercased()
        }
    }

    private func channelLabel(_ channels: Int?) -> String? {
        switch channels {
        case 1: return "MONO"
        case 2: return "STEREO"
        case 6: return "5.1"
        case 8: return "7.1"
        case let channels? where channels > 0: return "\(channels) CH"
        default: return nil
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

private struct PlaybackProcessingBadge: View {
    enum Style {
        case resolution
        case hardware
        case software
        case upscaling
        case audio
    }

    let label: String
    var systemImage: String?
    let style: Style

    var body: some View {
        Group {
            if let systemImage {
                Label(label, systemImage: systemImage)
            } else {
                Text(label)
            }
        }
        .font(.system(size: 16, weight: .bold, design: .rounded))
        .foregroundStyle(foreground)
        .lineLimit(1)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(background, in: Capsule())
        .overlay(Capsule().stroke(border, lineWidth: 1.5))
    }

    private var foreground: Color {
        style == .hardware ? Color.black.opacity(0.88) : primaryColor
    }

    private var background: Color {
        switch style {
        case .hardware: return Color(red: 0.38, green: 0.85, blue: 0.52)
        case .software: return TaterTheme.orange.opacity(0.16)
        case .upscaling: return Color.white.opacity(0.12)
        case .audio: return Color(red: 0.24, green: 0.67, blue: 0.76).opacity(0.15)
        case .resolution: return Color.black.opacity(0.36)
        }
    }

    private var border: Color {
        style == .hardware ? Color.clear : primaryColor.opacity(0.92)
    }

    private var primaryColor: Color {
        switch style {
        case .resolution, .software: return TaterTheme.orangeBright
        case .hardware: return Color.black
        case .upscaling: return Color.white.opacity(0.88)
        case .audio: return Color(red: 0.54, green: 0.88, blue: 0.96)
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
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
