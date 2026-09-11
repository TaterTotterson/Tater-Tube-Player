import AVFoundation
import Foundation

@MainActor
final class RecommendationSpeechCoordinator: NSObject, ObservableObject, AVAudioPlayerDelegate {
    enum State: Equatable {
        case idle
        case loading
        case speaking
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    private var client: APIClient?
    private var requestID: String?
    private var audioPlayer: AVAudioPlayer?
    private var work: Task<Void, Never>?
    private var generation = UUID()

    var statusText: String? {
        switch state {
        case .idle:
            return nil
        case .loading:
            return "Getting Tater’s voice…"
        case .speaking:
            return "Tater is speaking"
        case .failed(let message):
            return message
        }
    }

    func start(batchID: String, client: APIClient) {
        let batchID = batchID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !batchID.isEmpty else { return }

        stop()
        self.client = client
        state = .loading
        let currentGeneration = generation
        let startedAt = Date()

        work = Task { [weak self] in
            guard let self else { return }
            do {
                let created = try await client.createRecommendationSpeech(
                    batchID: batchID,
                    localHour: Calendar.current.component(.hour, from: Date())
                )
                try Task.checkCancellation()
                guard generation == currentGeneration, Self.isValidRequestID(created.id) else {
                    throw SpeechError.invalidRequest
                }
                requestID = created.id

                var requestState = created
                while Date().timeIntervalSince(startedAt) < 90 {
                    try Task.checkCancellation()
                    guard generation == currentGeneration else { return }
                    let status = requestState.status.lowercased()

                    if status == "ready" {
                        let audio = try await client.recommendationSpeechAudio(requestID: created.id)
                        try Task.checkCancellation()
                        guard generation == currentGeneration else { return }
                        try play(audio)
                        work = nil
                        return
                    }

                    if ["failed", "error", "canceled", "cancelled", "expired"].contains(status) {
                        throw SpeechError.server(requestState.error)
                    }

                    if status == "pending", Date().timeIntervalSince(startedAt) >= 15 {
                        throw SpeechError.unavailable
                    }

                    try await Task.sleep(for: .milliseconds(500))
                    requestState = try await client.recommendationSpeechStatus(requestID: created.id)
                }
                throw SpeechError.timedOut
            } catch is CancellationError {
                return
            } catch {
                guard generation == currentGeneration else { return }
                fail(error.localizedDescription)
            }
        }
    }

    func stop() {
        generation = UUID()
        work?.cancel()
        work = nil
        audioPlayer?.stop()
        audioPlayer = nil
        state = .idle

        let pendingID = requestID
        let pendingClient = client
        requestID = nil
        client = nil
        if let pendingID, let pendingClient {
            Task { await pendingClient.cancelRecommendationSpeech(requestID: pendingID) }
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in self?.stop() }
    }

    private func play(_ data: Data) throws {
        guard data.count >= 12,
              data.prefix(4) == Data("RIFF".utf8),
              data.dropFirst(8).prefix(4) == Data("WAVE".utf8)
        else {
            throw SpeechError.invalidAudio
        }
        let player = try AVAudioPlayer(data: data)
        player.delegate = self
        player.prepareToPlay()
        guard player.play() else { throw SpeechError.invalidAudio }
        audioPlayer = player
        state = .speaking
    }

    private func fail(_ message: String) {
        work?.cancel()
        work = nil
        audioPlayer?.stop()
        audioPlayer = nil
        let pendingID = requestID
        let pendingClient = client
        requestID = nil
        client = nil
        state = .failed(message)
        if let pendingID, let pendingClient {
            Task { await pendingClient.cancelRecommendationSpeech(requestID: pendingID) }
        }
    }

    private static func isValidRequestID(_ value: String) -> Bool {
        value.range(of: #"^[A-Za-z0-9_-]{1,128}$"#, options: .regularExpression) != nil
    }
}

private enum SpeechError: LocalizedError {
    case invalidRequest
    case invalidAudio
    case unavailable
    case timedOut
    case server(String?)

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Tater’s voice returned an invalid request. Your picks are ready below."
        case .invalidAudio:
            return "The voice message could not be played. Your picks are ready below."
        case .unavailable:
            return "Tater’s voice is not available right now. Your picks are ready below."
        case .timedOut:
            return "Tater’s voice is taking a little too long. Your picks are ready below."
        case .server(let message):
            let message = message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return message.isEmpty ? "Tater’s voice is unavailable right now. Your picks are ready below." : message
        }
    }
}
