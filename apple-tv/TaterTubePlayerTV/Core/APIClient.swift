import Foundation
import Network

enum TaterAPIError: LocalizedError {
    case invalidServerAddress
    case invalidResponse
    case server(Int, String)
    case rejected
    case insecureRemoteServer

    var errorDescription: String? {
        switch self {
        case .invalidServerAddress:
            return "Enter the address of your Tater Tube Server."
        case .invalidResponse:
            return "The server returned an invalid response."
        case .server(_, let message):
            return message
        case .rejected:
            return "The server rejected the request."
        case .insecureRemoteServer:
            return "Use HTTPS for a server outside your local network."
        }
    }
}

struct HomeResponse {
    let value: PlayerHome
    let encodedEnvelope: Data
}

struct LibraryRowsResult {
    let value: [LibraryRow]
    let encodedEnvelope: Data
}

struct LibraryPageResult {
    let value: LibraryPage
    let encodedEnvelope: Data
}

struct LiveGuideResult {
    let value: TubeTVGuide
    let encodedEnvelope: Data
}

final class APIClient: @unchecked Sendable {
    let serverURL: URL
    let token: String?

    private let session: URLSession
    private let decoder: JSONDecoder

    init(serverURL: URL, token: String? = nil) {
        self.serverURL = serverURL
        self.token = token

        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 60
        configuration.requestCachePolicy = .reloadRevalidatingCacheData
        configuration.urlCache = URLCache(
            memoryCapacity: 64 * 1024 * 1024,
            diskCapacity: 512 * 1024 * 1024,
            diskPath: "tater-tv-artwork"
        )
        session = URLSession(configuration: configuration, delegate: SameOriginRedirectDelegate(), delegateQueue: nil)

        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    static func normalizedServerURL(from input: String) throws -> URL {
        var value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw TaterAPIError.invalidServerAddress }
        if !value.contains("://") {
            value = "http://\(value)"
        }
        guard var components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host
        else {
            throw TaterAPIError.invalidServerAddress
        }
        if scheme == "http", !isLocalNetworkHost(host) {
            throw TaterAPIError.insecureRemoteServer
        }
        while components.path.count > 1 && components.path.hasSuffix("/") {
            components.path.removeLast()
        }
        guard let url = components.url else { throw TaterAPIError.invalidServerAddress }
        return url
    }

    private static func isLocalNetworkHost(_ host: String) -> Bool {
        let normalized = host.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        if normalized == "localhost" || normalized.hasSuffix(".local") {
            return true
        }
        if let address = IPv4Address(normalized) {
            let bytes = [UInt8](address.rawValue)
            guard bytes.count == 4 else { return false }
            return bytes[0] == 10
                || bytes[0] == 127
                || (bytes[0] == 169 && bytes[1] == 254)
                || (bytes[0] == 172 && (16...31).contains(bytes[1]))
                || (bytes[0] == 192 && bytes[1] == 168)
        }
        if let address = IPv6Address(normalized) {
            let bytes = [UInt8](address.rawValue)
            guard bytes.count == 16 else { return false }
            let loopback = bytes.dropLast().allSatisfy { $0 == 0 } && bytes.last == 1
            let uniqueLocal = bytes[0] & 0xfe == 0xfc
            let linkLocal = bytes[0] == 0xfe && bytes[1] & 0xc0 == 0x80
            return loopback || uniqueLocal || linkLocal
        }
        return !normalized.contains(".") && !normalized.contains(":")
    }

    func pair(pin: String) async throws -> PairResponse {
        let body = try JSONEncoder().encode(PairRequest(pin: pin, name: "Tater Tube Player"))
        let data = try await request(path: "/api/tater/players/pair", method: "POST", body: body, authenticated: false)
        return try decodeEnvelope(PairResponse.self, from: data)
    }

    func home() async throws -> HomeResponse {
        let data = try await request(path: "/api/v1/player/home?include_live=0")
        return HomeResponse(value: try decodeEnvelope(PlayerHome.self, from: data), encodedEnvelope: data)
    }

    func libraryRows(shuffleSeed: String) async throws -> LibraryRowsResult {
        let path = pathWithQuery(
            "/api/v1/player/library",
            items: [URLQueryItem(name: "shuffle_seed", value: shuffleSeed)]
        )
        let data = try await request(path: path)
        let response = try decodeEnvelope(LibraryRowsResponse.self, from: data)
        return LibraryRowsResult(value: response.rows, encodedEnvelope: data)
    }

    func libraryPage(at location: LibraryLocation, shuffleSeed: String) async throws -> LibraryPageResult {
        if location.continueWatching {
            let data = try await request(path: "/api/tater/playstate/continue")
            let page = try decodeEnvelope(LibraryPage.self, from: data)
            return LibraryPageResult(value: page, encodedEnvelope: data)
        }

        var query = [
            URLQueryItem(name: "category_id", value: location.categoryID),
            URLQueryItem(name: "title", value: location.title)
        ]
        if location.sourceIndex >= 0 {
            query.append(URLQueryItem(name: "source", value: String(location.sourceIndex)))
        }
        if !location.path.isEmpty {
            query.append(URLQueryItem(name: "path", value: location.path))
        }
        if location.categoryID.hasPrefix("local-discover:") {
            query.append(URLQueryItem(name: "full", value: "1"))
            query.append(URLQueryItem(name: "shuffle_seed", value: shuffleSeed))
        }
        let data = try await request(path: pathWithQuery("/api/tater/usenet/items", items: query))
        return LibraryPageResult(
            value: try decodeEnvelope(LibraryPage.self, from: data),
            encodedEnvelope: data
        )
    }

    func liveGuide() async throws -> LiveGuideResult {
        let data = try await request(path: "/api/tater/tv/lineup?window=player")
        return LiveGuideResult(
            value: try decodeEnvelope(TubeTVGuide.self, from: data),
            encodedEnvelope: data
        )
    }

    func playbackPlan(
        for item: MediaItem,
        capabilities: PlaybackCapabilitiesReport,
        audioTrack: Int? = nil
    ) async throws -> PlaybackPlan {
        guard let streamURL = item.streamURL, !streamURL.isEmpty else {
            throw TaterAPIError.invalidResponse
        }
        let payload = PlaybackSessionRequest(
            streamURL: streamURL,
            mediaType: item.mediaType ?? "video",
            profile: capabilities.profile,
            capabilities: capabilities,
            audioTrack: audioTrack
        )
        let body = try JSONEncoder().encode(payload)
        let data = try await request(
            path: "/api/v1/player/playback/sessions",
            method: "POST",
            body: body
        )
        return try decodeEnvelope(PlaybackPlan.self, from: data)
    }

    func savePlayState(
        for item: MediaItem,
        positionMS: Int64,
        durationMS: Int64,
        completed: Bool,
        playbackActive: Bool
    ) async throws {
        let payload = PlayStateRequest(
            item: item,
            positionMS: positionMS,
            durationMS: durationMS,
            completed: completed,
            playbackActive: playbackActive
        )
        _ = try await request(
            path: "/api/tater/playstate",
            method: "POST",
            body: try JSONEncoder().encode(payload)
        )
    }

    func clearPlayState(for item: MediaItem) async throws {
        let payload = PlayStateRequest(
            item: item,
            positionMS: 0,
            durationMS: 0,
            completed: true,
            playbackActive: false
        )
        _ = try await request(
            path: "/api/tater/playstate",
            method: "DELETE",
            body: try JSONEncoder().encode(payload)
        )
    }

    func nextEpisode(after item: MediaItem) async throws -> MediaItem? {
        guard let payload = NextEpisodeRequest(item: item) else { return nil }
        let data = try await request(
            path: "/api/tater/playstate/next",
            method: "POST",
            body: try JSONEncoder().encode(payload)
        )
        return try decodeEnvelope(NextEpisodeResponse.self, from: data).item
    }

    func artworkData(from value: String) async throws -> Data {
        guard let url = resolvedURL(for: value) else { throw TaterAPIError.invalidResponse }
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.cachePolicy = .returnCacheDataElseLoad
        if sameOrigin(url), let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return data
    }

    func decodeCachedHome(_ data: Data) throws -> PlayerHome {
        try decodeEnvelope(PlayerHome.self, from: data)
    }

    func decodeCachedLibraryRows(_ data: Data) throws -> [LibraryRow] {
        try decodeEnvelope(LibraryRowsResponse.self, from: data).rows
    }

    func decodeCachedLibraryPage(_ data: Data) throws -> LibraryPage {
        try decodeEnvelope(LibraryPage.self, from: data)
    }

    func decodeCachedLiveGuide(_ data: Data) throws -> TubeTVGuide {
        try decodeEnvelope(TubeTVGuide.self, from: data)
    }

    func localArtworkURL(for program: LiveProgram) -> String? {
        if let artwork = program.artworkValue { return artwork }
        guard let categoryID = program.categoryID, !categoryID.isEmpty,
              let path = program.path, !path.isEmpty
        else { return nil }
        return pathWithQuery(
            "/api/v1/player/artwork/local",
            items: [
                URLQueryItem(name: "category_id", value: categoryID),
                URLQueryItem(name: "source", value: String(program.sourceIndex)),
                URLQueryItem(name: "path", value: path),
                URLQueryItem(name: "thumbnail", value: "poster"),
                URLQueryItem(name: "player_token", value: token)
            ]
        )
    }

    private func pathWithQuery(_ path: String, items: [URLQueryItem]) -> String {
        var components = URLComponents()
        components.path = path
        components.queryItems = items
        return components.string ?? path
    }

    private func request(
        path: String,
        method: String = "GET",
        body: Data? = nil,
        authenticated: Bool = true
    ) async throws -> Data {
        guard let url = resolvedURL(for: path) else { throw TaterAPIError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if authenticated, let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return data
    }

    private func decodeEnvelope<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
        let envelope = try decoder.decode(APIEnvelope<Value>.self, from: data)
        if envelope.success == false { throw TaterAPIError.rejected }
        return envelope.data
    }

    private func resolvedURL(for value: String) -> URL? {
        if let absolute = URL(string: value), absolute.scheme != nil {
            return absolute
        }
        return URL(string: value, relativeTo: serverURL)?.absoluteURL
    }

    private func sameOrigin(_ url: URL) -> Bool {
        url.scheme?.lowercased() == serverURL.scheme?.lowercased()
            && url.host?.lowercased() == serverURL.host?.lowercased()
            && effectivePort(url) == effectivePort(serverURL)
    }

    private func effectivePort(_ url: URL) -> Int? {
        url.port ?? (url.scheme?.lowercased() == "https" ? 443 : 80)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let response = response as? HTTPURLResponse else {
            throw TaterAPIError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { $0["error"] as? String ?? $0["message"] as? String }
                ?? HTTPURLResponse.localizedString(forStatusCode: response.statusCode)
            throw TaterAPIError.server(response.statusCode, message)
        }
    }
}

private final class SameOriginRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let original = task.currentRequest?.url, let destination = request.url else {
            completionHandler(nil)
            return
        }

        let sameHost = original.host?.caseInsensitiveCompare(destination.host ?? "") == .orderedSame
        let samePort = effectivePort(original) == effectivePort(destination)
        let avoidsDowngrade = !(original.scheme == "https" && destination.scheme == "http")
        completionHandler(sameHost && samePort && avoidsDowngrade ? request : nil)
    }

    private func effectivePort(_ url: URL) -> Int? {
        url.port ?? (url.scheme?.lowercased() == "https" ? 443 : 80)
    }
}
