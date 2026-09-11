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

    private var client: APIClient?
    private var periodicObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var failureObservation: NSKeyValueObservation?
    private var basePositionMS: Int64 = 0
    private var isCompleting = false
    private var progressSaveInFlight = false

    var statusMessage: String {
        switch state {
        case .idle: return ""
        case .preparing: return "Matching playback to this Apple TV…"
        case .playing: return plan?.qualityLabel ?? "Playing"
        case .failed(let message): return message
        case .finished: return "Finished"
        }
    }

    func start(item: MediaItem, client: APIClient, resume: Bool) async {
        cleanupPlayer()
        self.client = client
        currentItem = item
        plan = nil
        state = .preparing
        shouldDismiss = false
        isCompleting = false

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
        if !isCompleting, !item.isLiveChannel {
            await saveProgress(item: item, completed: completed, active: false)
        }
        cleanupPlayer()
        currentItem = nil
        plan = nil
        client = nil
        state = .idle
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func clearProgress(for item: MediaItem) async throws {
        guard let client else { throw TaterAPIError.invalidResponse }
        try await client.clearPlayState(for: item)
    }

    private func beginPlayback(item: MediaItem, plan: PlaybackPlan, resume: Bool) async throws {
        guard var components = URLComponents(string: plan.streamURL) else {
            throw TaterAPIError.invalidResponse
        }

        let requestedResume = resume ? item.resumeOffsetMS : 0
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
        if !item.isLiveChannel {
            await saveProgress(item: item, completed: false, active: true)
        }
    }

    private func applyInitialMediaSelection(
        asset: AVAsset,
        playerItem: AVPlayerItem,
        plan: PlaybackPlan
    ) async {
        if let legible = try? await asset.loadMediaSelectionGroup(for: .legible) {
            playerItem.select(nil, in: legible)
        }

        guard plan.mode == "direct",
              plan.selectedAudioTrack >= 0,
              let audible = try? await asset.loadMediaSelectionGroup(for: .audible),
              audible.options.indices.contains(plan.selectedAudioTrack)
        else { return }
        playerItem.select(audible.options[plan.selectedAudioTrack], in: audible)
    }

    private func installObservers(on player: AVPlayer, item: AVPlayerItem) {
        periodicObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 15, preferredTimescale: 1),
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let item = self.currentItem else { return }
                await self.saveProgress(item: item, completed: false, active: true)
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
            isCompleting = false
            await start(item: next, client: client, resume: false)
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
            positionMS: completed ? durationMS : positionMS,
            durationMS: durationMS,
            completed: completed,
            playbackActive: active
        )
    }

    private var positionMS: Int64 {
        let current = player?.currentTime().seconds ?? 0
        return basePositionMS + Int64(max(0, current) * 1000)
    }

    private var durationMS: Int64 {
        if let item = currentItem, item.resolvedDurationMS > 0 {
            return item.resolvedDurationMS
        }
        let duration = player?.currentItem?.duration.seconds ?? 0
        guard duration.isFinite, duration > 0 else { return 0 }
        return basePositionMS + Int64(duration * 1000)
    }

    private var isNearEnd: Bool {
        let duration = durationMS
        guard duration > 0 else { return false }
        let remaining = duration - positionMS
        let threshold = duration < 300_000
            ? 10_000
            : max(30_000, min(300_000, duration / 20))
        return remaining <= threshold
    }

    private func cleanupPlayer() {
        if let periodicObserver, let player {
            player.removeTimeObserver(periodicObserver)
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        failureObservation?.invalidate()
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        periodicObserver = nil
        endObserver = nil
        failureObservation = nil
        player = nil
        basePositionMS = 0
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
        ["channel", "live", "tube_tv", "tubetv"].contains(mediaType?.lowercased() ?? "")
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
