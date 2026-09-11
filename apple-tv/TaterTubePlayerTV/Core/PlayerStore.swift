import CryptoKit
import Foundation

@MainActor
final class PlayerStore: ObservableObject {
    enum Phase: Equatable {
        case starting
        case pairing
        case ready
    }

    @Published private(set) var phase: Phase = .starting
    @Published private(set) var home: PlayerHome?
    @Published private(set) var connection: SavedConnection?
    @Published private(set) var isRefreshing = false
    @Published private(set) var isLibraryRefreshing = false
    @Published private(set) var libraryRows: [LibraryRow] = []
    @Published private(set) var libraryPages: [String: LibraryPage] = [:]
    @Published private(set) var loadingLibraryPages: Set<String> = []
    @Published private(set) var libraryErrors: [String: String] = [:]
    @Published private(set) var liveGuide: TubeTVGuide?
    @Published private(set) var isLiveGuideRefreshing = false
    @Published private(set) var liveGuideError: String?
    @Published private(set) var isDemo = false
    @Published var errorMessage: String?
    @Published var selectedMedia: MediaItem?
    @Published var isPlaybackPresented = false

    let playback = PlaybackCoordinator()

    private let credentials = CredentialStore()
    private var client: APIClient?
    private let homeCacheURL: URL
    private let libraryRowsCacheURL: URL
    private let libraryPagesCacheDirectory: URL
    private let liveGuideCacheURL: URL
    private let libraryShuffleSeed = UUID().uuidString
    private var lastLibraryLocation: LibraryLocation?

    init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let directory = caches.appendingPathComponent("TaterTubePlayerTV", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        homeCacheURL = directory.appendingPathComponent("home.json")
        libraryRowsCacheURL = directory.appendingPathComponent("library-rows.json")
        liveGuideCacheURL = directory.appendingPathComponent("live-guide.json")
        libraryPagesCacheDirectory = directory.appendingPathComponent("library-pages", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: libraryPagesCacheDirectory,
            withIntermediateDirectories: true
        )

        if ProcessInfo.processInfo.arguments.contains("--demo") {
            isDemo = true
            home = DemoCatalog.home
            libraryRows = DemoCatalog.libraryRows
            liveGuide = DemoCatalog.liveGuide
            phase = .ready
        }
    }

    var serverURL: URL? { connection?.serverURL }
    var token: String? { connection?.token }

    func start() async {
        guard phase == .starting else { return }
        guard let saved = credentials.load() else {
            phase = .pairing
            return
        }

        connection = saved
        client = APIClient(serverURL: saved.serverURL, token: saved.token)
        loadCachedHome()
        loadCachedLibraryRows()
        loadCachedLiveGuide()
        phase = .ready
        await refreshHome(showActivity: home == nil)
        await refreshLibraryRows(showActivity: libraryRows.isEmpty)
        if home?.capabilities.tubeTV == true {
            await refreshLiveGuide(showActivity: liveGuide == nil)
        }
    }

    func pair(serverAddress: String, pin: String) async {
        errorMessage = nil
        do {
            let serverURL = try APIClient.normalizedServerURL(from: serverAddress)
            let pairingClient = APIClient(serverURL: serverURL)
            let response = try await pairingClient.pair(pin: pin)
            let saved = SavedConnection(
                serverURL: serverURL,
                token: response.token,
                playerName: response.playerName ?? "Tater Tube Player"
            )
            try credentials.save(saved)
            connection = saved
            client = APIClient(serverURL: serverURL, token: response.token)
            isDemo = false
            phase = .ready
            await refreshHome(showActivity: true)
            await refreshLibraryRows(showActivity: true)
            if home?.capabilities.tubeTV == true {
                await refreshLiveGuide(showActivity: true)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func enterDemo() {
        connection = nil
        client = nil
        isDemo = true
        home = DemoCatalog.home
        libraryRows = DemoCatalog.libraryRows
        liveGuide = DemoCatalog.liveGuide
        libraryPages.removeAll()
        errorMessage = nil
        phase = .ready
    }

    func refreshHome(showActivity: Bool = false) async {
        guard !isDemo, let client else { return }
        if showActivity { isRefreshing = true }
        defer { isRefreshing = false }

        do {
            let response = try await client.home()
            home = response.value
            try? response.encodedEnvelope.write(to: homeCacheURL, options: .atomic)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            if home == nil { phase = .pairing }
        }
    }

    func artworkData(for value: String) async throws -> Data {
        guard let client else { throw TaterAPIError.invalidResponse }
        return try await client.artworkData(from: value)
    }

    func guideArtworkURL(for program: LiveProgram) -> String? {
        client?.localArtworkURL(for: program) ?? program.artworkValue
    }

    func refreshLiveGuide(showActivity: Bool = false) async {
        guard !isDemo, !isLiveGuideRefreshing, let client else { return }
        isLiveGuideRefreshing = true
        defer { isLiveGuideRefreshing = false }

        do {
            let response = try await client.liveGuide()
            liveGuide = response.value
            try? response.encodedEnvelope.write(to: liveGuideCacheURL, options: .atomic)
            liveGuideError = nil
        } catch {
            if liveGuide == nil {
                liveGuideError = error.localizedDescription
            }
        }
    }

    func refreshLibraryRows(showActivity: Bool = false) async {
        guard !isDemo, let client else { return }
        if showActivity { isLibraryRefreshing = true }
        defer { isLibraryRefreshing = false }

        do {
            let response = try await client.libraryRows(shuffleSeed: libraryShuffleSeed)
            if response.value != libraryRows {
                libraryRows = response.value
            }
            try? response.encodedEnvelope.write(to: libraryRowsCacheURL, options: .atomic)
            errorMessage = nil
        } catch {
            if libraryRows.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
    }

    func libraryPage(for location: LibraryLocation) -> LibraryPage? {
        libraryPages[location.cacheKey]
    }

    func loadLibraryPage(_ location: LibraryLocation, forceNetwork: Bool = false) async {
        let key = location.cacheKey
        lastLibraryLocation = location

        if isDemo {
            libraryPages[key] = DemoCatalog.libraryPage(for: location)
            return
        }

        if libraryPages[key] == nil {
            loadCachedLibraryPage(for: location)
        }
        guard !loadingLibraryPages.contains(key), let client else { return }

        loadingLibraryPages.insert(key)
        defer { loadingLibraryPages.remove(key) }
        do {
            let response = try await client.libraryPage(at: location, shuffleSeed: libraryShuffleSeed)
            if response.value != libraryPages[key] {
                libraryPages[key] = response.value
            }
            try? response.encodedEnvelope.write(to: libraryPageCacheURL(for: location), options: .atomic)
            libraryErrors[key] = nil
        } catch {
            if libraryPages[key] == nil || forceNetwork {
                libraryErrors[key] = error.localizedDescription
            }
        }
    }

    func openDetails(for item: MediaItem) {
        selectedMedia = item
    }

    func play(_ item: MediaItem, resume: Bool) async {
        guard !isDemo, let client else {
            errorMessage = "Pair with your Tater Tube Server to play this title."
            return
        }
        selectedMedia = nil
        isPlaybackPresented = true
        await playback.start(item: item, client: client, resume: resume)
    }

    func play(_ channel: LiveChannel) async {
        await play(channel.playbackItem, resume: false)
    }

    func stopPlayback() async {
        await playback.stop()
        isPlaybackPresented = false
        await refreshHome()
        if let lastLibraryLocation {
            await loadLibraryPage(lastLibraryLocation, forceNetwork: true)
        }
    }

    func clearProgress(for item: MediaItem) async {
        guard let client else { return }
        do {
            try await client.clearPlayState(for: item)
            selectedMedia = nil
            await refreshHome()
            if let lastLibraryLocation {
                await loadLibraryPage(lastLibraryLocation, forceNetwork: true)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func disconnect() {
        credentials.clear()
        try? FileManager.default.removeItem(at: homeCacheURL)
        try? FileManager.default.removeItem(at: libraryRowsCacheURL)
        try? FileManager.default.removeItem(at: liveGuideCacheURL)
        try? FileManager.default.removeItem(at: libraryPagesCacheDirectory)
        try? FileManager.default.createDirectory(
            at: libraryPagesCacheDirectory,
            withIntermediateDirectories: true
        )
        connection = nil
        client = nil
        selectedMedia = nil
        isPlaybackPresented = false
        home = nil
        libraryRows = []
        libraryPages = [:]
        loadingLibraryPages = []
        libraryErrors = [:]
        liveGuide = nil
        liveGuideError = nil
        lastLibraryLocation = nil
        isDemo = false
        errorMessage = nil
        phase = .pairing
    }

    private func loadCachedHome() {
        guard let client, let data = try? Data(contentsOf: homeCacheURL) else { return }
        home = try? client.decodeCachedHome(data)
    }

    private func loadCachedLibraryRows() {
        guard let client, let data = try? Data(contentsOf: libraryRowsCacheURL) else { return }
        libraryRows = (try? client.decodeCachedLibraryRows(data)) ?? []
    }

    private func loadCachedLiveGuide() {
        guard let client, let data = try? Data(contentsOf: liveGuideCacheURL) else { return }
        liveGuide = try? client.decodeCachedLiveGuide(data)
    }

    private func loadCachedLibraryPage(for location: LibraryLocation) {
        guard let client,
              let data = try? Data(contentsOf: libraryPageCacheURL(for: location)),
              let page = try? client.decodeCachedLibraryPage(data)
        else { return }
        libraryPages[location.cacheKey] = page
    }

    private func libraryPageCacheURL(for location: LibraryLocation) -> URL {
        let digest = SHA256.hash(data: Data(location.cacheKey.utf8))
        let filename = digest.map { String(format: "%02x", $0) }.joined() + ".json"
        return libraryPagesCacheDirectory.appendingPathComponent(filename)
    }
}
