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
    @Published private(set) var isDemo = false
    @Published var errorMessage: String?

    private let credentials = CredentialStore()
    private var client: APIClient?
    private let homeCacheURL: URL

    init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let directory = caches.appendingPathComponent("TaterTubePlayerTV", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        homeCacheURL = directory.appendingPathComponent("home.json")

        if ProcessInfo.processInfo.arguments.contains("--demo") {
            isDemo = true
            home = DemoCatalog.home
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
        phase = .ready
        await refreshHome(showActivity: home == nil)
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
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func enterDemo() {
        connection = nil
        client = nil
        isDemo = true
        home = DemoCatalog.home
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

    func disconnect() {
        credentials.clear()
        try? FileManager.default.removeItem(at: homeCacheURL)
        connection = nil
        client = nil
        home = nil
        isDemo = false
        errorMessage = nil
        phase = .pairing
    }

    private func loadCachedHome() {
        guard let client, let data = try? Data(contentsOf: homeCacheURL) else { return }
        home = try? client.decodeCachedHome(data)
    }
}
