import Foundation

enum TaterAPIError: LocalizedError {
    case invalidServerAddress
    case invalidResponse
    case server(Int, String)
    case rejected

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
        }
    }
}

struct HomeResponse {
    let value: PlayerHome
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
              components.host != nil
        else {
            throw TaterAPIError.invalidServerAddress
        }
        while components.path.count > 1 && components.path.hasSuffix("/") {
            components.path.removeLast()
        }
        guard let url = components.url else { throw TaterAPIError.invalidServerAddress }
        return url
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
