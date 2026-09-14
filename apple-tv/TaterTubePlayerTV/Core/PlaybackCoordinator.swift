import AVFoundation
import AVKit
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
    private var displayCriteriaTask: Task<Void, Never>?
    private var endObserver: NSObjectProtocol?
    private var failedToEndObserver: NSObjectProtocol?
    private var failureObservation: NSKeyValueObservation?
    private var audibleGroup: AVMediaSelectionGroup?
    private var legibleGroup: AVMediaSelectionGroup?
    private var selectedSubtitleIndex = -1
    private var basePositionMS: Int64 = 0
    private var pendingSeekTargetMS: Int64?
    private var streamSeekTask: Task<Void, Never>?
    private var isCompleting = false
    private var progressSaveInFlight = false
    private var reportsViewing = false
    private var viewingSessionID = ""
    private var viewingWatchedMS: Int64 = 0
    private var viewingLastSampleAt: Date?
    private var hasReportedViewingStart = false
    private var prematureHLSRecoveryAttempts = 0
    private var playbackPlanCacheKey: String?
    private var playbackPlanWasCached = false
    private var playbackPlanRecoveryAttempts = 0
    private var playbackRecoveryInFlight = false

    private var activeDisplayManager: AVDisplayManager? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        return (windows.first(where: \.isKeyWindow) ?? windows.first)?.avDisplayManager
    }

    var statusMessage: String {
        switch state {
        case .idle: return ""
        case .preparing: return "Starting playback…"
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
            outputAudioChannels: 6,
            sourceVideoRange: "hdr10",
            outputVideoRange: "hdr10",
            outputFrameRate: nil,
            selectedAudioTrack: 0,
            source: PlaybackMediaInfo(
                container: "mkv",
                durationSeconds: 6_720,
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
        streamSeekTask?.cancel()
        streamSeekTask = nil
        pendingSeekTargetMS = nil
        cleanupPlayer()
        prematureHLSRecoveryAttempts = 0
        playbackPlanCacheKey = nil
        playbackPlanWasCached = false
        playbackPlanRecoveryAttempts = 0
        playbackRecoveryInFlight = false
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
            let lookup = try await requestPlaybackPlan(for: item)
            let plan = lookup.plan
            debugPlayback(
                "plan mode=\(plan.mode) cached=\(lookup.wasCached) container=\(plan.outputContainer ?? "unknown") " +
                "video=\(plan.videoMode)/\(plan.videoCodec ?? "unknown") " +
                "audio=\(plan.audioMode)/\(plan.audioCodec ?? "unknown") " +
                "target=\(sanitizedStreamDescription(plan.streamURL))"
            )
            applyPlaybackPlan(lookup)
            do {
                try await beginPlayback(item: item, plan: plan, resume: resume)
            } catch {
                guard !Task.isCancelled else { throw error }
                playbackPlanRecoveryAttempts = 1
                debugPlayback(
                    "initial stream failed; rebuilding capabilities and media plan: " +
                    diagnosticDescription(error)
                )
                let refreshed = try await requestPlaybackPlan(for: item, forceRefresh: true)
                applyPlaybackPlan(refreshed)
                try await beginPlayback(item: item, plan: refreshed.plan, resume: resume)
            }
        } catch {
            guard !Task.isCancelled else { return }
            debugPlayback("start failed: \(diagnosticDescription(error))")
            state = .failed(error.localizedDescription)
        }
    }

    func stop() async {
        streamSeekTask?.cancel()
        streamSeekTask = nil
        pendingSeekTargetMS = nil
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
        prematureHLSRecoveryAttempts = 0
        playbackPlanCacheKey = nil
        playbackPlanWasCached = false
        playbackPlanRecoveryAttempts = 0
        playbackRecoveryInFlight = false
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
        guard !currentItemIsLive, plan != nil else { return }
        let durationMS = currentDurationMS
        let originMS = pendingSeekTargetMS ?? currentPositionMS
        let unclampedTarget = max(0, originMS + Int64(seconds * 1000))
        // Starting a converted stream exactly at EOF cannot produce an HLS
        // segment. Keep the target just inside the playable source instead.
        let lastPlayableMS = durationMS > 1_000 ? durationMS - 1_000 : durationMS
        let targetMS = durationMS > 0 ? min(lastPlayableMS, unclampedTarget) : unclampedTarget
        pendingSeekTargetMS = targetMS
        playbackPositionMS = targetMS
        playbackControlMessage = "Seeking…"
        streamSeekTask?.cancel()
        streamSeekTask = Task { [weak self] in
            // Keep showing the current video while the user moves the timeline.
            // Commit once after the seek burst instead of repeatedly replacing
            // AVPlayer/HLS sessions and bouncing the television out of HDR mode.
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled, let self else { return }
            await self.commitSeek(at: targetMS)
        }
    }

    private func commitSeek(at positionMS: Int64) async {
        guard pendingSeekTargetMS == positionMS, let player else { return }

        if plan?.mode.lowercased() == "direct" {
            await player.seek(
                to: CMTime(value: positionMS, timescale: 1000),
                toleranceBefore: CMTime(seconds: 0.25, preferredTimescale: 1000),
                toleranceAfter: CMTime(seconds: 0.25, preferredTimescale: 1000)
            )
            guard pendingSeekTargetMS == positionMS else { return }
            pendingSeekTargetMS = nil
            playbackControlMessage = nil
            updatePlaybackDisplay()
            return
        }

        // Converted/remuxed HLS has only a short local seekable runway. Open one
        // replacement stream at the settled source position while the old player
        // continues displaying its current frame and audio.
        await restartConvertedStream(at: positionMS)
    }

    private func restartConvertedStream(at positionMS: Int64) async {
        guard let item = currentItem, let plan else { return }
        let remainPaused = isPaused

        do {
            try await beginPlayback(
                item: item,
                plan: plan,
                resume: false,
                positionOverrideMS: positionMS,
                preserveDisplayCriteria: true
            )
            if pendingSeekTargetMS == positionMS {
                pendingSeekTargetMS = nil
            }
            playbackControlMessage = nil
            if remainPaused {
                player?.pause()
                isPaused = true
            }
        } catch {
            guard !Task.isCancelled, currentItem != nil else { return }
            if pendingSeekTargetMS == positionMS {
                pendingSeekTargetMS = nil
            }
            debugPlayback("seek restart failed: \(diagnosticDescription(error))")
            if player != nil {
                if !remainPaused {
                    player?.play()
                    isPaused = false
                }
                playbackControlMessage = "That position was not ready. Playback resumed."
                state = .playing
                updatePlaybackDisplay()
            } else {
                state = .failed(error.localizedDescription)
            }
        }
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
              client != nil,
              let currentPlan = plan,
              let tracks = currentPlan.source.audioTracks,
              tracks.count > 1,
              !isChangingAudioTrack
        else { return }

        let current = tracks.firstIndex { $0.index == currentPlan.selectedAudioTrack } ?? 0
        let nextTrack = tracks[(current + 1) % tracks.count]
        let resumeAt = currentPositionMS
        let previousPlan = plan
        let previousCacheKey = playbackPlanCacheKey
        let previousWasCached = playbackPlanWasCached
        isChangingAudioTrack = true
        defer { isChangingAudioTrack = false }

        do {
            let replacement = try await requestPlaybackPlan(
                for: item,
                audioTrack: nextTrack.index
            )
            player?.pause()
            applyPlaybackPlan(replacement)
            state = .preparing
            try await beginPlayback(
                item: item,
                plan: replacement.plan,
                resume: false,
                positionOverrideMS: resumeAt,
                preserveDisplayCriteria: true
            )
        } catch {
            guard !Task.isCancelled else { return }
            plan = previousPlan
            playbackPlanCacheKey = previousCacheKey
            playbackPlanWasCached = previousWasCached
            playbackControlMessage = "That audio track could not be selected."
            if player == nil {
                state = .failed(error.localizedDescription)
            } else {
                player?.play()
                state = .playing
            }
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

    private func requestPlaybackPlan(
        for item: MediaItem,
        audioTrack: Int? = nil,
        forceRefresh: Bool = false
    ) async throws -> PlaybackPlanLookup {
        guard let client else { throw TaterAPIError.invalidResponse }
        let capabilities = PlaybackCapabilityProfileCache.shared.report(
            for: item,
            forceRefresh: forceRefresh
        )
        if forceRefresh {
            client.invalidatePlaybackPlan(cacheKey: playbackPlanCacheKey)
        }
        return try await client.playbackPlan(
            for: item,
            capabilities: capabilities,
            audioTrack: audioTrack,
            forceRefresh: forceRefresh
        )
    }

    private func applyPlaybackPlan(_ lookup: PlaybackPlanLookup) {
        plan = lookup.plan
        playbackPlanCacheKey = lookup.cacheKey
        playbackPlanWasCached = lookup.wasCached
    }

    private func beginPlayback(
        item: MediaItem,
        plan: PlaybackPlan,
        resume: Bool,
        positionOverrideMS: Int64? = nil,
        preserveDisplayCriteria: Bool = false
    ) async throws {
        guard var components = URLComponents(string: plan.streamURL) else {
            throw TaterAPIError.invalidResponse
        }

        let requestedResume = positionOverrideMS ?? (resume ? item.resumeOffsetMS : 0)
        if plan.mode != "direct", requestedResume > 0 {
            var query = components.queryItems ?? []
            query.removeAll { $0.name == "start" }
            query.append(URLQueryItem(
                name: "start",
                value: String(format: "%.3f", Double(requestedResume) / 1000)
            ))
            components.queryItems = query
        }
        if plan.mode != "direct", !item.isLiveChannel {
            var query = components.queryItems ?? []
            query.removeAll { $0.name == "tater_hls_generation" }
            query.append(URLQueryItem(name: "tater_hls_generation", value: UUID().uuidString.lowercased()))
            components.queryItems = query
        }
        guard let url = components.url else { throw TaterAPIError.invalidResponse }

        let asset = AVURLAsset(url: url)
        let outputContainer = plan.outputContainer?.lowercased() ?? ""
        let shouldPreflight = plan.mode == "direct"
            || outputContainer == "hls"
            || url.pathExtension.lowercased() == "m3u8"
        if shouldPreflight {
            guard try await asset.load(.isPlayable) else {
                throw PlaybackError.notPlayable
            }
            try Task.checkCancellation()
            debugPlayback("asset is playable: \(sanitizedStreamDescription(url.absoluteString))")
        } else {
            // Converted/remuxed player streams are progressive and intentionally
            // have no static byte length. Preloading `isPlayable` makes AVFoundation
            // issue a two-byte range probe, which cannot describe that live output.
            debugPlayback("opening progressive stream: \(sanitizedStreamDescription(url.absoluteString))")
        }

        // For a converted seek or audio-track change, keep the old player and
        // its last frame alive while AVFoundation waits for the replacement
        // playlist. Swap only after the new stream is genuinely playable.
        cleanupPlayer(resetDisplayCriteria: !preserveDisplayCriteria)
        basePositionMS = plan.mode == "direct" ? 0 : requestedResume
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)
        player.appliesMediaSelectionCriteriaAutomatically = false
        self.player = player
        applyPreferredDisplayCriteria(for: asset, playerItem: playerItem)

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
        guard plan.mode == "direct" else {
            audibleGroup = nil
            legibleGroup = nil
            selectedSubtitleIndex = -1
            subtitleTrackLabel = "CC Off"
            audioTrackLabel = audioLabel(for: plan)
            return
        }

        audibleGroup = try? await asset.loadMediaSelectionGroup(for: .audible)
        legibleGroup = try? await asset.loadMediaSelectionGroup(for: .legible)
        selectedSubtitleIndex = -1
        subtitleTrackLabel = "CC Off"
        if let legibleGroup {
            playerItem.select(nil, in: legibleGroup)
        }

        guard plan.selectedAudioTrack >= 0,
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

    private func applyPreferredDisplayCriteria(
        for asset: AVAsset,
        playerItem: AVPlayerItem
    ) {
        displayCriteriaTask?.cancel()
        displayCriteriaTask = Task { [weak self, weak playerItem] in
            do {
                let criteria = try await asset.load(.preferredDisplayCriteria)
                guard !Task.isCancelled,
                      let self,
                      let playerItem,
                      self.player?.currentItem === playerItem
                else { return }

                guard let displayManager = self.activeDisplayManager else {
                    self.debugPlayback("preferred display criteria skipped: no active window")
                    return
                }
                displayManager.preferredDisplayCriteria = criteria
                self.debugPlayback(
                    "applied preferred display criteria; matching_enabled=" +
                    "\(displayManager.isDisplayCriteriaMatchingEnabled)"
                )
            } catch {
                guard !Task.isCancelled else { return }
                self?.debugPlayback(
                    "preferred display criteria unavailable: \(self?.diagnosticDescription(error) ?? error.localizedDescription)"
                )
            }
        }
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

        failedToEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] notification in
            let failure = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.debugPlayback("failed to play to end: \(self.diagnosticDescription(failure ?? item.error))")
                await self.handlePlaybackFailure(
                    failure ?? item.error,
                    failedPlayerItem: item
                )
            }
        }

        failureObservation = item.observe(\.status, options: [.new]) { [weak self] observed, _ in
            guard observed.status == .failed else { return }
            let message = observed.error?.localizedDescription ?? "This video could not be played."
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.debugPlayback("player item failed: \(self.diagnosticDescription(observed.error))")
                await self.handlePlaybackFailure(
                    observed.error ?? PlaybackError.message(message),
                    failedPlayerItem: observed
                )
            }
        }
    }

    private func handlePlaybackFailure(
        _ error: Error?,
        failedPlayerItem: AVPlayerItem
    ) async {
        guard player?.currentItem === failedPlayerItem else { return }
        let message = error?.localizedDescription ?? "This video could not be played."
        guard !playbackRecoveryInFlight else { return }

        if playbackPlanRecoveryAttempts < 1,
           let item = currentItem,
           !isCompleting {
            playbackRecoveryInFlight = true
            playbackPlanRecoveryAttempts += 1
            debugPlayback("refreshing failed playback plan; cached=\(playbackPlanWasCached)")
            let resumeAt = currentPositionMS
            let selectedTrack = (plan?.selectedAudioTrack ?? -1) >= 0
                ? plan?.selectedAudioTrack
                : nil
            state = .preparing
            playbackControlMessage = "Refreshing playback compatibility…"

            do {
                let replacement = try await requestPlaybackPlan(
                    for: item,
                    audioTrack: selectedTrack,
                    forceRefresh: true
                )
                applyPlaybackPlan(replacement)
                try await beginPlayback(
                    item: item,
                    plan: replacement.plan,
                    resume: false,
                    positionOverrideMS: resumeAt,
                    preserveDisplayCriteria: true
                )
                playbackControlMessage = nil
                playbackRecoveryInFlight = false
                return
            } catch {
                guard !Task.isCancelled, currentItem != nil else {
                    playbackRecoveryInFlight = false
                    return
                }
                debugPlayback("fresh playback-plan recovery failed: \(diagnosticDescription(error))")
            }
            playbackRecoveryInFlight = false
        }

        state = .failed(message)
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func handlePlaybackEnd() async {
        guard !isCompleting, let item = currentItem, let client else { return }
        if await recoverPrematureHLSEndIfNeeded(item: item) {
            return
        }
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

    /// AVPlayer can occasionally report the end of a growing EVENT playlist
    /// when playback catches its current live edge. Discovery HLS has a known
    /// source duration, so continue from that edge instead of marking a partial
    /// movie complete. A new `start` query creates a fresh, buffered HLS session.
    private func recoverPrematureHLSEndIfNeeded(item: MediaItem) async -> Bool {
        guard !item.isLiveChannel,
              plan?.mode.lowercased() != "direct",
              let durationSeconds = plan?.source.durationSeconds,
              durationSeconds.isFinite,
              durationSeconds > 0
        else { return false }

        let expectedDurationMS = Int64(durationSeconds * 1000)
        let positionMS = currentPositionMS
        let remainingMS = expectedDurationMS - positionMS
        guard remainingMS > 15_000 else { return false }

        guard prematureHLSRecoveryAttempts < 3 else {
            debugPlayback(
                "converted stream repeatedly ended early; position_ms=\(positionMS) " +
                "expected_ms=\(expectedDurationMS)"
            )
            if reportsViewing {
                await reportViewing(item: item, state: "stopped")
            }
            await saveProgress(item: item, completed: false, active: false)
            state = .failed("The stream ended before the source finished. Choose Resume to try again.")
            UIApplication.shared.isIdleTimerDisabled = false
            return true
        }

        prematureHLSRecoveryAttempts += 1
        debugPlayback(
            "recovering premature HLS end; attempt=\(prematureHLSRecoveryAttempts) " +
            "position_ms=\(positionMS) expected_ms=\(expectedDurationMS)"
        )
        isPaused = false
        await restartConvertedStream(at: max(0, positionMS - 1_000))
        return true
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
        playbackPositionMS = pendingSeekTargetMS ?? currentPositionMS
        playbackDurationMS = currentDurationMS
        isPaused = player?.timeControlStatus == .paused
    }

    private var currentItemIsLive: Bool {
        currentItem?.isLiveChannel == true
    }

    private var currentPositionMS: Int64 {
        let current = player?.currentTime().seconds ?? 0
        guard current.isFinite else { return basePositionMS }
        return basePositionMS + Int64(max(0, current) * 1000)
    }

    private var currentDurationMS: Int64 {
        if let durationSeconds = plan?.source.durationSeconds,
           durationSeconds.isFinite,
           durationSeconds > 0 {
            return Int64(durationSeconds * 1000)
        }
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

    private func cleanupPlayer(resetDisplayCriteria: Bool = true) {
        displayCriteriaTask?.cancel()
        displayCriteriaTask = nil
        if resetDisplayCriteria {
            activeDisplayManager?.preferredDisplayCriteria = nil
        }
        if let periodicObserver, let player {
            player.removeTimeObserver(periodicObserver)
        }
        if let displayObserver, let player {
            player.removeTimeObserver(displayObserver)
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        if let failedToEndObserver {
            NotificationCenter.default.removeObserver(failedToEndObserver)
        }
        failureObservation?.invalidate()
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        periodicObserver = nil
        displayObserver = nil
        endObserver = nil
        failedToEndObserver = nil
        failureObservation = nil
        player = nil
        basePositionMS = 0
        audibleGroup = nil
        legibleGroup = nil
        selectedSubtitleIndex = -1
        audioTrackLabel = "Audio"
        subtitleTrackLabel = "CC Off"
    }

    private func sanitizedStreamDescription(_ value: String) -> String {
        guard let components = URLComponents(string: value) else { return "invalid-url" }
        let keys = (components.queryItems ?? []).map(\.name).sorted().joined(separator: ",")
        let port = components.port.map { ":\($0)" } ?? ""
        return "\(components.scheme ?? "?")://\(components.host ?? "?")\(port)\(components.path) query=[\(keys)]"
    }

    private func diagnosticDescription(_ error: Error?) -> String {
        guard let error else { return "no error supplied" }
        let value = error as NSError
        let underlying = (value.userInfo[NSUnderlyingErrorKey] as? NSError)
            .map { " underlying=\($0.domain)(\($0.code)): \($0.localizedDescription)" } ?? ""
        return "\(value.domain)(\(value.code)): \(value.localizedDescription)\(underlying)"
    }

    private func debugPlayback(_ message: String) {
#if DEBUG
        print("[TaterPlayback] \(message)")
#endif
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
            details.append(displayAudioCodec(codec))
        }
        if let channels = track?.channels ?? plan.source.audioChannels, channels > 0 {
            details.append(audioChannelLabel(channels))
        }
        if plan.audioMode.lowercased() == "transcode" {
            var output: [String] = []
            if let codec = plan.audioCodec, !codec.isEmpty {
                output.append(displayAudioCodec(codec))
            }
            if let channels = plan.outputAudioChannels, channels > 0 {
                output.append(audioChannelLabel(channels))
            }
            if !output.isEmpty {
                details.append("→ " + output.joined(separator: " "))
            }
        }
        return details.isEmpty ? "Audio" : "Audio · " + details.joined(separator: " · ")
    }

    private func displayAudioCodec(_ value: String) -> String {
        switch value.lowercased() {
        case "dts_hd", "dts-hd": return "DTS-HD MA"
        case "eac3": return "E-AC-3"
        case "ac3": return "AC-3"
        case "truehd": return "TRUEHD"
        default: return value.uppercased()
        }
    }

    private func audioChannelLabel(_ channels: Int) -> String {
        switch channels {
        case 8: return "7.1"
        case 6: return "5.1"
        case 2: return "Stereo"
        default: return "\(channels)ch"
        }
    }
}

private enum PlaybackError: LocalizedError {
    case notPlayable
    case message(String)

    var errorDescription: String? {
        switch self {
        case .notPlayable:
            return "This server stream is not compatible with Apple TV."
        case .message(let value):
            return value
        }
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
        if let durationSeconds, durationSeconds > 0 {
            return Int64(durationSeconds * 1000)
        }
        // Tater Tube Server's media-item `duration` field is expressed in
        // seconds. Play-state offsets use milliseconds, but duration does not.
        if let duration, duration > 0 { return duration * 1000 }
        return 0
    }
}
