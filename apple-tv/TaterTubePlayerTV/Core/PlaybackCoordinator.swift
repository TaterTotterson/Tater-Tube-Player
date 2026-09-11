import AVFoundation
import Foundation
import UIKit

@MainActor
final class PlaybackCoordinator: ObservableObject {
    enum State: Equatable {
        case idle
        case preparing
        case playing
        case failed(String)
        case finished
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var currentItem: MediaItem?
    @Published private(set) var plan: PlaybackPlan?
    @Published private(set) var player: AVPlayer?
    @Published private(set) var shouldDismiss = false
    @Published private(set) var playbackPositionMS: Int64 = 0
    @Published private(set) var playbackDurationMS: Int64 = 0
    @Published private(set) var isPaused = false
    @Published private(set) var audioTrackLabel = "Audio"
    @Published private(set) var subtitleTrackLabel = "CC Off"
    @Published private(set) var playbackControlMessage: String?
    @Published private(set) var isChangingAudioTrack = false

    private var client: APIClient?
    private var periodicObserver: Any?
    private var displayObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var failureObservation: NSKeyValueObservation?
    private var audibleGroup: AVMediaSelectionGroup?
    private var legibleGroup: AVMediaSelectionGroup?
    private var selectedSubtitleIndex = -1
    private var basePositionMS: Int64 = 0
    private var isCompleting = false
    private var progressSaveInFlight = false
    private var reportsViewing = false
    private var viewingSessionID = ""
    private var viewingWatchedMS: Int64 = 0
    private var viewingLastSampleAt: Date?
    private var hasReportedViewingStart = false

    var statusMessage: String {
        switch state {
        case .idle: return ""
        case .preparing: return "Matching playback to this Apple TV…"
        case .playing: return plan?.qualityLabel ?? "Playing"
        case .failed(let message): return message
        case .finished: return "Finished"
        }
    }

#if DEBUG
    func configureOverlayPreview() {
        currentItem = MediaItem(
            id: "overlay-preview",
            title: "Cosmic Drift",
            mediaType: "movie",
            durationSeconds: 6_720
        )
        plan = PlaybackPlan(
            streamURL: "preview://overlay",
            mode: "audio_transcode",
            videoMode: "direct",
            audioMode: "transcode",
            videoCodec: "hevc",
            audioCodec: "aac",
            qualityLabel: "Video Direct · Audio Transcode",
            reason: "The video is compatible; audio is converted for Apple TV.",
            resolutionLabel: "4K",
            outputContainer: "mpegts",
            selectedAudioTrack: 0,
            source: PlaybackMediaInfo(
                container: "mkv",
                videoCodec: "hevc",
                width: 3840,
                height: 2160,
                videoRange: "hdr10",
                audioCodec: "truehd",
                audioChannels: 8,
                audioTracks: [
                    PlaybackAudioTrack(
                        index: 0,
                        streamIndex: 1,
                        codec: "truehd",
                        channels: 8,
                        language: "eng",
                        title: "Main 7.1",
                        isDefault: true,
                        commentary: false,
                        descriptive: false
                    ),
                    PlaybackAudioTrack(
                        index: 1,
                        streamIndex: 2,
                        codec: "ac3",
                        channels: 6,
                        language: "eng",
                        title: "Main 5.1",
                        isDefault: false,
                        commentary: false,
                        descriptive: false
                    )
                ]
            )
        )
        player = AVPlayer()
        state = .playing
        playbackPositionMS = 2_588_000
        playbackDurationMS = 6_720_000
        audioTrackLabel = "Audio · ENG · AAC · 5.1"
        subtitleTrackLabel = "CC Off"
        isPaused = false
    }
#endif

    func start(
        item: MediaItem,
        client: APIClient,
        resume: Bool,
        reportsViewing: Bool = false
    ) async {
        cleanupPlayer()
        self.client = client
        currentItem = item
        plan = nil
        state = .preparing
        shouldDismiss = false
        isCompleting = false
        playbackControlMessage = nil
        isPaused = false
        self.reportsViewing = reportsViewing
        viewingSessionID = UUID().uuidString.lowercased()
        viewingWatchedMS = 0
        viewingLastSampleAt = nil
        hasReportedViewingStart = false

        do {
            let capabilities = PlaybackCapabilitiesReport.current
            let plan = try await client.playbackPlan(for: item, capabilities: capabilities)
            self.plan = plan
            try await beginPlayback(item: item, plan: plan, resume: resume)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func stop() async {
        guard let item = currentItem else {
            cleanupPlayer()
            return
        }

        let completed = state == .finished || isNearEnd
        if reportsViewing {
            await reportViewing(item: item, state: completed ? "completed" : "stopped")
        }
        if !isCompleting, !item.isLiveChannel {
            await saveProgress(item: item, completed: completed, active: false)
        }
        cleanupPlayer()
        currentItem = nil
        plan = nil
        client = nil
        state = .idle
        playbackPositionMS = 0
        playbackDurationMS = 0
        isPaused = false
        resetViewingSession()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func clearProgress(for item: MediaItem) async throws {
        guard let client else { throw TaterAPIError.invalidResponse }
        try await client.clearPlayState(for: item)
    }

    func togglePlayPause() {
        guard let player else { return }
        if player.timeControlStatus == .playing {
            player.pause()
            isPaused = true
        } else {
            player.play()
            isPaused = false
        }
        updatePlaybackDisplay()
    }

    func seek(by seconds: Double) {
        guard !currentItemIsLive, let player else { return }
        let targetMS = max(0, min(currentDurationMS, currentPositionMS + Int64(seconds * 1000)))
        let relativeMS = max(0, targetMS - basePositionMS)
        player.seek(
            to: CMTime(value: relativeMS, timescale: 1000),
            toleranceBefore: CMTime(seconds: 0.15, preferredTimescale: 1000),
            toleranceAfter: CMTime(seconds: 0.15, preferredTimescale: 1000)
        )
        playbackPositionMS = targetMS
    }

    var hasMultipleAudioTracks: Bool {
        max(audibleGroup?.options.count ?? 0, plan?.source.audioTracks?.count ?? 0) > 1
    }

    var hasSubtitles: Bool {
        !(legibleGroup?.options.isEmpty ?? true)
    }

    func cycleAudioTrack() async {
        playbackControlMessage = nil
        guard hasMultipleAudioTracks, let playerItem = player?.currentItem else { return }

        if let audibleGroup, audibleGroup.options.count > 1 {
            let selected = playerItem.currentMediaSelection.selectedMediaOption(in: audibleGroup)
            let current = selected.flatMap { audibleGroup.options.firstIndex(of: $0) } ?? -1
            let next = (current + 1) % audibleGroup.options.count
            let option = audibleGroup.options[next]
            playerItem.select(option, in: audibleGroup)
            audioTrackLabel = audioLabel(for: option)
            return
        }

        guard let item = currentItem,
              let client,
              let currentPlan = plan,
              let tracks = currentPlan.source.audioTracks,
              tracks.count > 1,
              !isChangingAudioTrack
        else { return }

        let current = tracks.firstIndex { $0.index == currentPlan.selectedAudioTrack } ?? 0
        let nextTrack = tracks[(current + 1) % tracks.count]
        let resumeAt = currentPositionMS
        isChangingAudioTrack = true
        defer { isChangingAudioTrack = false }

        do {
            let replacement = try await client.playbackPlan(
                for: item,
                capabilities: PlaybackCapabilitiesReport.current,
                audioTrack: nextTrack.index
            )
            cleanupPlayer()
            plan = replacement
            state = .preparing
            try await beginPlayback(
                item: item,
                plan: replacement,
                resume: false,
                positionOverrideMS: resumeAt
            )
        } catch {
            playbackControlMessage = "That audio track could not be selected."
            if player == nil { state = .failed(error.localizedDescription) }
        }
    }

    func cycleSubtitleTrack() {
        playbackControlMessage = nil
        guard let legibleGroup, let playerItem = player?.currentItem,
              !legibleGroup.options.isEmpty
        else { return }

        selectedSubtitleIndex += 1
        if selectedSubtitleIndex >= legibleGroup.options.count {
            selectedSubtitleIndex = -1
            playerItem.select(nil, in: legibleGroup)
            subtitleTrackLabel = "CC Off"
        } else {
            let option = legibleGroup.options[selectedSubtitleIndex]
            playerItem.select(option, in: legibleGroup)
            subtitleTrackLabel = "CC · \(option.displayName)"
        }
    }

    private func beginPlayback(
        item: MediaItem,
        plan: PlaybackPlan,
        resume: Bool,
        positionOverrideMS: Int64? = nil
    ) async throws {
        guard var components = URLComponents(string: plan.streamURL) else {
            throw TaterAPIError.invalidResponse
        }

        let requestedResume = positionOverrideMS ?? (resume ? item.resumeOffsetMS : 0)
        basePositionMS = plan.mode == "direct" ? 0 : requestedResume
        if plan.mode != "direct", requestedResume > 0 {
            var query = components.queryItems ?? []
            query.removeAll { $0.name == "start" }
            query.append(URLQueryItem(
                name: "start",
                value: String(format: "%.3f", Double(requestedResume) / 1000)
            ))
            components.queryItems = query
        }
        guard let url = components.url else { throw TaterAPIError.invalidResponse }

        let asset = AVURLAsset(url: url)
        guard try await asset.load(.isPlayable) else {
            throw PlaybackError.notPlayable
        }

        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)
        player.appliesMediaSelectionCriteriaAutomatically = false
        self.player = player

        await applyInitialMediaSelection(asset: asset, playerItem: playerItem, plan: plan)
        installObservers(on: player, item: playerItem)

        if plan.mode == "direct", requestedResume > 0 {
            let time = CMTime(value: requestedResume, timescale: 1000)
            await player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        }

        UIApplication.shared.isIdleTimerDisabled = true
        player.play()
        state = .playing
        isPaused = false
        updatePlaybackDisplay()
        viewingLastSampleAt = Date()
        if !item.isLiveChannel {
            await saveProgress(item: item, completed: false, active: true)
        }
    }

    private func applyInitialMediaSelection(
        asset: AVAsset,
        playerItem: AVPlayerItem,
        plan: PlaybackPlan
    ) async {
        audibleGroup = try? await asset.loadMediaSelectionGroup(for: .audible)
        legibleGroup = try? await asset.loadMediaSelectionGroup(for: .legible)
        selectedSubtitleIndex = -1
        subtitleTrackLabel = "CC Off"
        if let legibleGroup {
            playerItem.select(nil, in: legibleGroup)
        }

        guard plan.mode == "direct",
              plan.selectedAudioTrack >= 0,
              let audibleGroup,
              audibleGroup.options.indices.contains(plan.selectedAudioTrack)
        else {
            audioTrackLabel = audioLabel(for: plan)
            return
        }
        let option = audibleGroup.options[plan.selectedAudioTrack]
        playerItem.select(option, in: audibleGroup)
        audioTrackLabel = audioLabel(for: option)
    }

    private func installObservers(on player: AVPlayer, item: AVPlayerItem) {
        displayObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 10),
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.updatePlaybackDisplay() }
        }

        periodicObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 15, preferredTimescale: 1),
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let item = self.currentItem else { return }
                await self.saveProgress(item: item, completed: false, active: true)
                await self.reportViewing(
                    item: item,
                    state: self.hasReportedViewingStart ? "progress" : "started"
                )
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.handlePlaybackEnd() }
        }

        failureObservation = item.observe(\.status, options: [.new]) { [weak self] observed, _ in
            guard observed.status == .failed else { return }
            let message = observed.error?.localizedDescription ?? "This video could not be played."
            Task { @MainActor [weak self] in
                self?.state = .failed(message)
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
    }

    private func handlePlaybackEnd() async {
        guard !isCompleting, let item = currentItem, let client else { return }
        isCompleting = true
        if reportsViewing {
            await reportViewing(item: item, state: "completed")
        }
        if item.isLiveChannel {
            state = .finished
            shouldDismiss = true
            UIApplication.shared.isIdleTimerDisabled = false
            return
        }
        await saveProgress(item: item, completed: true, active: false)

        if item.mediaType?.lowercased() == "episode",
           item.categoryID?.lowercased().hasPrefix("local:") == true,
           let next = try? await client.nextEpisode(after: item),
           next.streamURL != nil {
            let shouldReportViewing = reportsViewing
            isCompleting = false
            await start(
                item: next,
                client: client,
                resume: false,
                reportsViewing: shouldReportViewing
            )
            return
        }

        state = .finished
        shouldDismiss = true
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func saveProgress(item: MediaItem, completed: Bool, active: Bool) async {
        guard !item.isLiveChannel, let client else { return }
        if progressSaveInFlight {
            // Routine heartbeats may be coalesced, but a stop/completion update
            // must win so Continue Watching is correct as soon as playback exits.
            guard completed || !active else { return }
            for _ in 0..<40 where progressSaveInFlight {
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
        progressSaveInFlight = true
        defer { progressSaveInFlight = false }
        try? await client.savePlayState(
            for: item,
            positionMS: completed ? currentDurationMS : currentPositionMS,
            durationMS: currentDurationMS,
            completed: completed,
            playbackActive: active
        )
    }

    private func reportViewing(item: MediaItem, state: String) async {
        guard reportsViewing, let client else { return }
        updateViewingWatchTime()
        guard viewingWatchedMS > 0 else { return }
        try? await client.saveViewingEvent(
            for: item,
            state: state,
            positionMS: currentPositionMS,
            durationMS: currentDurationMS,
            sessionID: viewingSessionID,
            watchedMS: viewingWatchedMS
        )
        hasReportedViewingStart = true
    }

    private func updateViewingWatchTime() {
        let now = Date()
        defer { viewingLastSampleAt = now }
        guard player?.timeControlStatus == .playing,
              let last = viewingLastSampleAt
        else { return }
        let elapsed = min(max(now.timeIntervalSince(last), 0), 20)
        viewingWatchedMS += Int64(elapsed * 1000)
    }

    private func resetViewingSession() {
        reportsViewing = false
        viewingSessionID = ""
        viewingWatchedMS = 0
        viewingLastSampleAt = nil
        hasReportedViewingStart = false
    }

    private func updatePlaybackDisplay() {
        playbackPositionMS = currentPositionMS
        playbackDurationMS = currentDurationMS
        isPaused = player?.timeControlStatus == .paused
    }

    private var currentItemIsLive: Bool {
        currentItem?.isLiveChannel == true
    }

    private var currentPositionMS: Int64 {
        let current = player?.currentTime().seconds ?? 0
        return basePositionMS + Int64(max(0, current) * 1000)
    }

    private var currentDurationMS: Int64 {
        if let item = currentItem, item.resolvedDurationMS > 0 {
            return item.resolvedDurationMS
        }
        let duration = player?.currentItem?.duration.seconds ?? 0
        guard duration.isFinite, duration > 0 else { return 0 }
        return basePositionMS + Int64(duration * 1000)
    }

    private var isNearEnd: Bool {
        let duration = currentDurationMS
        guard duration > 0 else { return false }
        let remaining = duration - currentPositionMS
        let threshold = duration < 300_000
            ? 10_000
            : max(30_000, min(300_000, duration / 20))
        return remaining <= threshold
    }

    private func cleanupPlayer() {
        if let periodicObserver, let player {
            player.removeTimeObserver(periodicObserver)
        }
        if let displayObserver, let player {
            player.removeTimeObserver(displayObserver)
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        failureObservation?.invalidate()
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        periodicObserver = nil
        displayObserver = nil
        endObserver = nil
        failureObservation = nil
        player = nil
        basePositionMS = 0
        audibleGroup = nil
        legibleGroup = nil
        selectedSubtitleIndex = -1
        audioTrackLabel = "Audio"
        subtitleTrackLabel = "CC Off"
    }

    private func audioLabel(for option: AVMediaSelectionOption) -> String {
        let name = option.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Audio" : "Audio · \(name)"
    }

    private func audioLabel(for plan: PlaybackPlan) -> String {
        let track = plan.source.audioTracks?.first { $0.index == plan.selectedAudioTrack }
        var details: [String] = []
        if let language = track?.language, !language.isEmpty {
            details.append(language.uppercased())
        }
        if let title = track?.title, !title.isEmpty {
            details.append(title)
        }
        if let codec = track?.codec ?? plan.audioCodec, !codec.isEmpty {
            details.append(codec.replacingOccurrences(of: "eac3", with: "E-AC-3").uppercased())
        }
        if let channels = track?.channels ?? plan.source.audioChannels, channels > 0 {
            details.append(channels == 6 ? "5.1" : (channels == 8 ? "7.1" : "\(channels)ch"))
        }
        return details.isEmpty ? "Audio" : "Audio · " + details.joined(separator: " · ")
    }
}

private enum PlaybackError: LocalizedError {
    case notPlayable

    var errorDescription: String? {
        "This server stream is not compatible with Apple TV."
    }
}

extension MediaItem {
    var isLiveChannel: Bool {
        ["channel", "live", "tube_tv", "tubetv"].contains(type?.lowercased() ?? "")
            || ["channel", "live", "tube_tv", "tubetv"].contains(mediaType?.lowercased() ?? "")
    }

    var resumeOffsetMS: Int64 {
        if let viewOffset, viewOffset > 0 { return viewOffset }
        if let viewOffsetSeconds, viewOffsetSeconds > 0 {
            return Int64(viewOffsetSeconds * 1000)
        }
        return 0
    }

    var resolvedDurationMS: Int64 {
        if let duration, duration > 0 { return duration }
        if let durationSeconds, durationSeconds > 0 {
            return Int64(durationSeconds * 1000)
        }
        return 0
    }
}
