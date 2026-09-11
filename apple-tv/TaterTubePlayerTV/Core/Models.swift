import Foundation

struct APIEnvelope<Value: Decodable>: Decodable {
    let success: Bool?
    let data: Value
}

struct PairRequest: Encodable {
    let pin: String
    let name: String
}

struct PairResponse: Decodable {
    let token: String
    let playerName: String?
}

struct PlayerHome: Decodable, Equatable {
    let protocolVersion: String?
    let serverName: String
    let serverVersion: String?
    let capabilities: PlayerCapabilities
    let hero: HomeHero?
    let continueWatching: [MediaItem]
    let recentlyAdded: [MediaItem]
    let liveChannels: [LiveChannel]
    let libraries: [LibraryEntry]
    let warnings: [String]

    init(
        protocolVersion: String? = nil,
        serverName: String,
        serverVersion: String? = nil,
        capabilities: PlayerCapabilities = .empty,
        hero: HomeHero? = nil,
        continueWatching: [MediaItem] = [],
        recentlyAdded: [MediaItem] = [],
        liveChannels: [LiveChannel] = [],
        libraries: [LibraryEntry] = [],
        warnings: [String] = []
    ) {
        self.protocolVersion = protocolVersion
        self.serverName = serverName
        self.serverVersion = serverVersion
        self.capabilities = capabilities
        self.hero = hero
        self.continueWatching = continueWatching
        self.recentlyAdded = recentlyAdded
        self.liveChannels = liveChannels
        self.libraries = libraries
        self.warnings = warnings
    }

    private enum CodingKeys: String, CodingKey {
        case protocolVersion
        case serverName
        case serverVersion
        case capabilities
        case hero
        case continueWatching
        case recentlyAdded
        case liveChannels
        case libraries
        case warnings
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        protocolVersion = try values.decodeIfPresent(String.self, forKey: .protocolVersion)
        serverName = try values.decodeIfPresent(String.self, forKey: .serverName) ?? "Tater Tube Server"
        serverVersion = try values.decodeIfPresent(String.self, forKey: .serverVersion)
        capabilities = try values.decodeIfPresent(PlayerCapabilities.self, forKey: .capabilities) ?? .empty
        hero = try values.decodeIfPresent(HomeHero.self, forKey: .hero)
        continueWatching = try values.decodeIfPresent([MediaItem].self, forKey: .continueWatching) ?? []
        recentlyAdded = try values.decodeIfPresent([MediaItem].self, forKey: .recentlyAdded) ?? []
        liveChannels = try values.decodeIfPresent([LiveChannel].self, forKey: .liveChannels) ?? []
        libraries = try values.decodeIfPresent([LibraryEntry].self, forKey: .libraries) ?? []
        warnings = try values.decodeIfPresent([String].self, forKey: .warnings) ?? []
    }
}

struct PlayerCapabilities: Decodable, Equatable {
    let localMedia: Bool
    let newznab: Bool
    let tubeTV: Bool
    let commercials: Bool
    let taterLink: Bool

    static let empty = PlayerCapabilities(
        localMedia: false,
        newznab: false,
        tubeTV: false,
        commercials: false,
        taterLink: false
    )

    init(
        localMedia: Bool = false,
        newznab: Bool = false,
        tubeTV: Bool = false,
        commercials: Bool = false,
        taterLink: Bool = false
    ) {
        self.localMedia = localMedia
        self.newznab = newznab
        self.tubeTV = tubeTV
        self.commercials = commercials
        self.taterLink = taterLink
    }

    private enum CodingKeys: String, CodingKey {
        case localMedia
        case newznab
        case tubeTV
        case commercials
        case taterLink
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        localMedia = try values.decodeIfPresent(Bool.self, forKey: .localMedia) ?? false
        newznab = try values.decodeIfPresent(Bool.self, forKey: .newznab) ?? false
        tubeTV = try values.decodeIfPresent(Bool.self, forKey: .tubeTV) ?? false
        commercials = try values.decodeIfPresent(Bool.self, forKey: .commercials) ?? false
        taterLink = try values.decodeIfPresent(Bool.self, forKey: .taterLink) ?? false
    }
}

struct HomeHero: Decodable, Equatable {
    let personalized: Bool?
    let eyebrow: String?
    let message: String?
    let assistantName: String?
}

struct LibraryEntry: Decodable, Equatable, Identifiable {
    let id: String
    let title: String
    let type: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case type
    }

    init(id: String, title: String, type: String? = nil) {
        self.id = id
        self.title = title
        self.type = type
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        title = try values.decodeIfPresent(String.self, forKey: .title) ?? "Library"
        type = try values.decodeIfPresent(String.self, forKey: .type)
        id = try values.decodeFlexibleStringIfPresent(forKey: .id)
            ?? [type, title].compactMap { $0 }.joined(separator: ":")
    }
}

struct MediaItem: Decodable, Equatable, Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let summary: String?
    let mediaType: String?
    let date: String?
    let poster: String?
    let backdrop: String?
    let streamURL: String?
    let progressPercent: Double?
    let viewOffset: Int64?
    let duration: Int64?
    let demoArtworkName: String?

    init(
        id: String,
        title: String,
        subtitle: String? = nil,
        summary: String? = nil,
        mediaType: String? = nil,
        date: String? = nil,
        poster: String? = nil,
        backdrop: String? = nil,
        streamURL: String? = nil,
        progressPercent: Double? = nil,
        viewOffset: Int64? = nil,
        duration: Int64? = nil,
        demoArtworkName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.summary = summary
        self.mediaType = mediaType
        self.date = date
        self.poster = poster
        self.backdrop = backdrop
        self.streamURL = streamURL
        self.progressPercent = progressPercent
        self.viewOffset = viewOffset
        self.duration = duration
        self.demoArtworkName = demoArtworkName
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case subtitle
        case summary
        case overview
        case mediaType
        case date
        case poster
        case backdrop
        case streamURL = "streamUrl"
        case progressPercent
        case viewOffset
        case duration
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        title = try values.decode(String.self, forKey: .title)
        mediaType = try values.decodeIfPresent(String.self, forKey: .mediaType)
        poster = try values.decodeIfPresent(String.self, forKey: .poster)
        backdrop = try values.decodeIfPresent(String.self, forKey: .backdrop)
        streamURL = try values.decodeIfPresent(String.self, forKey: .streamURL)
        subtitle = try values.decodeIfPresent(String.self, forKey: .subtitle)
        summary = try values.decodeIfPresent(String.self, forKey: .summary)
            ?? values.decodeIfPresent(String.self, forKey: .overview)
        date = try values.decodeIfPresent(String.self, forKey: .date)
        progressPercent = try values.decodeIfPresent(Double.self, forKey: .progressPercent)
        viewOffset = try values.decodeFlexibleInt64IfPresent(forKey: .viewOffset)
        duration = try values.decodeFlexibleInt64IfPresent(forKey: .duration)
        demoArtworkName = nil
        id = try values.decodeFlexibleStringIfPresent(forKey: .id)
            ?? [mediaType, title, date].compactMap { $0 }.joined(separator: ":")
    }
}

struct LiveChannel: Decodable, Equatable, Identifiable {
    let id: String
    let number: String
    let title: String
    let logoURL: String?
    let streamURL: String?
    let now: LiveProgram?
    let next: LiveProgram?

    private enum CodingKeys: String, CodingKey {
        case id
        case number
        case title
        case logoURL = "logoUrl"
        case streamURL = "streamUrl"
        case now
        case next
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        number = try values.decodeIfPresent(String.self, forKey: .number) ?? ""
        title = try values.decode(String.self, forKey: .title)
        logoURL = try values.decodeIfPresent(String.self, forKey: .logoURL)
        streamURL = try values.decodeIfPresent(String.self, forKey: .streamURL)
        now = try values.decodeIfPresent(LiveProgram.self, forKey: .now)
        next = try values.decodeIfPresent(LiveProgram.self, forKey: .next)
        id = try values.decodeFlexibleStringIfPresent(forKey: .id)
            ?? [number, title].joined(separator: ":")
    }
}

struct LiveProgram: Decodable, Equatable {
    let title: String
    let progressPercent: Double?
    let poster: String?
}

private extension KeyedDecodingContainer {
    func decodeFlexibleStringIfPresent(forKey key: Key) throws -> String? {
        if let string = try? decodeIfPresent(String.self, forKey: key) {
            return string
        }
        if let integer = try? decodeIfPresent(Int64.self, forKey: key) {
            return String(integer)
        }
        return nil
    }

    func decodeFlexibleInt64IfPresent(forKey key: Key) throws -> Int64? {
        if let integer = try? decodeIfPresent(Int64.self, forKey: key) {
            return integer
        }
        if let number = try? decodeIfPresent(Double.self, forKey: key) {
            return Int64(number)
        }
        if let string = try? decodeIfPresent(String.self, forKey: key) {
            return Int64(string)
        }
        return nil
    }
}

enum DemoCatalog {
    static let home = PlayerHome(
        protocolVersion: "1",
        serverName: "Tater Tube Demo",
        serverVersion: "demo",
        capabilities: PlayerCapabilities(
            localMedia: true,
            newznab: true,
            tubeTV: true,
            commercials: true,
            taterLink: true
        ),
        hero: HomeHero(
            personalized: false,
            eyebrow: "GOOD EVENING",
            message: "Everything good, right where you left it.",
            assistantName: "Tater"
        ),
        continueWatching: [
            MediaItem(id: "cosmic", title: "Cosmic Drift", subtitle: "42 minutes remaining", mediaType: "movie", date: "2026", progressPercent: 38, demoArtworkName: "cosmic-drift-poster"),
            MediaItem(id: "harbor", title: "Harbor Street", subtitle: "Season 2 · Episode 4", mediaType: "episode", date: "2026", progressPercent: 64, demoArtworkName: "harbor-street"),
            MediaItem(id: "winter", title: "The Long Winter", subtitle: "Continue watching", mediaType: "movie", date: "2025", progressPercent: 17, demoArtworkName: "the-long-winter")
        ],
        recentlyAdded: [
            MediaItem(id: "neon", title: "Neon Nights", mediaType: "movie", date: "2026", demoArtworkName: "neon-nights"),
            MediaItem(id: "north", title: "Northern Lights", mediaType: "show", date: "2026", demoArtworkName: "northern-lights"),
            MediaItem(id: "orange", title: "Orange County Skies", mediaType: "movie", date: "2025", demoArtworkName: "orange-county-skies"),
            MediaItem(id: "midnight", title: "After Midnight", mediaType: "show", date: "2025", demoArtworkName: "after-midnight")
        ],
        liveChannels: [],
        libraries: [
            LibraryEntry(id: "local:movies", title: "Movies", type: "local"),
            LibraryEntry(id: "local:tv", title: "TV Shows", type: "local")
        ]
    )
}
