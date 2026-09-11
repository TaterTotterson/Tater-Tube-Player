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

struct LibraryRow: Decodable, Equatable, Identifiable {
    let title: String
    let entry: LibraryEntry
    let items: [MediaItem]

    var id: String { entry.id.isEmpty ? title : entry.id }
}

struct LibraryPage: Decodable, Equatable {
    let title: String
    let items: [MediaItem]

    init(title: String, items: [MediaItem]) {
        self.title = title
        self.items = items
    }

    private enum CodingKeys: String, CodingKey {
        case title
        case items
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        title = try values.decodeIfPresent(String.self, forKey: .title) ?? "Library"
        items = try values.decodeIfPresent([MediaItem].self, forKey: .items) ?? []
    }
}

struct LibraryRowsResponse: Decodable {
    let rows: [LibraryRow]
}

struct DiscoverCatalogResponse: Decodable {
    let categories: [DiscoverCategory]

    var discoveryCategories: [DiscoverCategory] {
        for category in categories where category.id.lowercased() == "stream" {
            if let root = category.children.first(where: {
                $0.type?.lowercased() == "discoverroot"
            }) {
                return root.children
            }
        }
        return []
    }
}

struct DiscoverCategory: Decodable, Equatable, Identifiable {
    let id: String
    let title: String
    let detail: String?
    let type: String?
    let fullTitle: String?
    let category: String?
    let time: String?
    let children: [DiscoverCategory]

    init(
        id: String,
        title: String,
        detail: String? = nil,
        type: String? = "discover",
        fullTitle: String? = nil,
        category: String? = nil,
        time: String? = nil,
        children: [DiscoverCategory] = []
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.type = type
        self.fullTitle = fullTitle
        self.category = category
        self.time = time
        self.children = children
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, detail, type, fullTitle, category, time, children
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        title = try values.decodeIfPresent(String.self, forKey: .title) ?? "Discover"
        detail = try values.decodeIfPresent(String.self, forKey: .detail)
        type = try values.decodeIfPresent(String.self, forKey: .type)
        fullTitle = try values.decodeIfPresent(String.self, forKey: .fullTitle)
        category = try values.decodeIfPresent(String.self, forKey: .category)
        time = try values.decodeIfPresent(String.self, forKey: .time)
        children = try values.decodeIfPresent([DiscoverCategory].self, forKey: .children) ?? []
        id = try values.decodeFlexibleStringIfPresent(forKey: .id)
            ?? [type, title].compactMap { $0 }.joined(separator: ":")
    }

    var artworkName: String {
        switch id.lowercased() {
        case "movie:top": return "popular-movies"
        case let value where value.hasPrefix("movie:year:"): return "new-movies"
        case "movie:imdbrating": return "featured-movies"
        case "series:top": return "popular-tv"
        case let value where value.hasPrefix("series:year:"): return "new-tv"
        case "series:imdbrating": return "featured-tv"
        default: return category?.lowercased() == "series" ? "featured-tv" : "featured-movies"
        }
    }
}

struct DiscoverPreparedFile: Identifiable {
    let id: String
    let filename: String
    let playbackItem: MediaItem
}

struct DiscoverPlaybackResponse: Decodable {
    let streams: [DiscoverStream]
    let playStateID: String?
    let nzbURL: String?

    private enum CodingKeys: String, CodingKey {
        case streams
        case playStateID = "_tater_play_state_id"
        case nzbURL = "_tater_nzb_url"
    }
}

struct DiscoverStream: Decodable {
    let url: String
    let title: String?
    let name: String?

    private enum CodingKeys: String, CodingKey {
        case url
        case streamURL = "streamUrl"
        case title
        case name
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        url = try values.decodeIfPresent(String.self, forKey: .url)
            ?? values.decodeIfPresent(String.self, forKey: .streamURL)
            ?? ""
        title = try values.decodeIfPresent(String.self, forKey: .title)
        name = try values.decodeIfPresent(String.self, forKey: .name)
    }
}

struct DiscoverPlayRequest: Encodable {
    let nzbURL: String
    let title: String
    let category: String
    let timeout: Int

    private enum CodingKeys: String, CodingKey {
        case nzbURL = "nzb_url"
        case title, category, timeout
    }
}

struct LibraryLocation: Hashable, Identifiable {
    let categoryID: String
    let title: String
    let sourceIndex: Int
    let path: String
    let continueWatching: Bool
    let backdrop: String?
    let poster: String?
    let summary: String?
    let mediaType: String?
    let demoArtworkName: String?

    var id: String { cacheKey }

    var cacheKey: String {
        [categoryID, String(sourceIndex), path, continueWatching ? "continue" : "browse"]
            .joined(separator: "|")
    }

    static let allMovies = LibraryLocation(
        categoryID: "local-discover:movies",
        title: "All Movies",
        sourceIndex: -1,
        path: "",
        continueWatching: false,
        backdrop: nil,
        poster: nil,
        summary: nil,
        mediaType: "movie",
        demoArtworkName: nil
    )

    static let allShows = LibraryLocation(
        categoryID: "local-discover:series",
        title: "All TV Shows",
        sourceIndex: -1,
        path: "",
        continueWatching: false,
        backdrop: nil,
        poster: nil,
        summary: nil,
        mediaType: "show",
        demoArtworkName: nil
    )

    init(
        categoryID: String,
        title: String,
        sourceIndex: Int = -1,
        path: String = "",
        continueWatching: Bool = false,
        backdrop: String? = nil,
        poster: String? = nil,
        summary: String? = nil,
        mediaType: String? = nil,
        demoArtworkName: String? = nil
    ) {
        self.categoryID = categoryID
        self.title = title
        self.sourceIndex = sourceIndex
        self.path = path
        self.continueWatching = continueWatching
        self.backdrop = backdrop
        self.poster = poster
        self.summary = summary
        self.mediaType = mediaType
        self.demoArtworkName = demoArtworkName
    }

    init(entry: LibraryEntry) {
        categoryID = entry.id
        title = entry.title
        sourceIndex = -1
        path = ""
        continueWatching = entry.type?.lowercased() == "continue"
        backdrop = nil
        poster = nil
        summary = nil
        mediaType = nil
        demoArtworkName = nil
    }

    init(item: MediaItem, parent: LibraryLocation) {
        categoryID = item.categoryID ?? parent.categoryID
        title = item.title
        sourceIndex = item.sourceIndex
        path = item.path ?? ""
        continueWatching = false
        backdrop = item.backdrop ?? parent.backdrop
        poster = item.seriesPoster ?? item.seasonPoster ?? item.poster ?? parent.poster
        summary = item.summary ?? parent.summary
        mediaType = item.mediaType
        demoArtworkName = item.demoArtworkName ?? parent.demoArtworkName
    }
}

struct MediaItem: Decodable, Equatable, Identifiable {
    let id: String
    let title: String
    let type: String?
    let subtitle: String?
    let summary: String?
    let tagline: String?
    let contentRating: String?
    let communityRating: Double?
    let mediaType: String?
    let category: String?
    let categoryID: String?
    let sourceIndex: Int
    let path: String?
    let playStateID: String?
    let seriesStateID: String?
    let seriesTitle: String?
    let nzbURL: String?
    let discoverStreamIndex: Int
    let discoverSourceTitle: String?
    let searchQuery: String?
    let guid: String?
    let sizeText: String?
    let files: String?
    let grabs: String?
    let date: String?
    let poster: String?
    let backdrop: String?
    let seriesPoster: String?
    let seasonPoster: String?
    let episodeStill: String?
    let streamURL: String?
    let progressPercent: Double?
    let viewOffset: Int64?
    let viewOffsetSeconds: Double?
    let duration: Int64?
    let durationSeconds: Double?
    let durationDisplay: String?
    let leafCount: Int
    let seasonCount: Int
    let episodeCount: Int
    let resumeTitle: String?
    let resumeItem: ResumeMediaItem?
    let demoArtworkName: String?

    init(
        id: String,
        title: String,
        type: String? = nil,
        subtitle: String? = nil,
        summary: String? = nil,
        tagline: String? = nil,
        contentRating: String? = nil,
        communityRating: Double? = nil,
        mediaType: String? = nil,
        category: String? = nil,
        categoryID: String? = nil,
        sourceIndex: Int = 0,
        path: String? = nil,
        playStateID: String? = nil,
        seriesStateID: String? = nil,
        seriesTitle: String? = nil,
        nzbURL: String? = nil,
        discoverStreamIndex: Int = 0,
        discoverSourceTitle: String? = nil,
        searchQuery: String? = nil,
        guid: String? = nil,
        sizeText: String? = nil,
        files: String? = nil,
        grabs: String? = nil,
        date: String? = nil,
        poster: String? = nil,
        backdrop: String? = nil,
        seriesPoster: String? = nil,
        seasonPoster: String? = nil,
        episodeStill: String? = nil,
        streamURL: String? = nil,
        progressPercent: Double? = nil,
        viewOffset: Int64? = nil,
        viewOffsetSeconds: Double? = nil,
        duration: Int64? = nil,
        durationSeconds: Double? = nil,
        durationDisplay: String? = nil,
        leafCount: Int = 0,
        seasonCount: Int = 0,
        episodeCount: Int = 0,
        resumeTitle: String? = nil,
        resumeItem: ResumeMediaItem? = nil,
        demoArtworkName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.subtitle = subtitle
        self.summary = summary
        self.tagline = tagline
        self.contentRating = contentRating
        self.communityRating = communityRating
        self.mediaType = mediaType
        self.category = category
        self.categoryID = categoryID
        self.sourceIndex = sourceIndex
        self.path = path
        self.playStateID = playStateID
        self.seriesStateID = seriesStateID
        self.seriesTitle = seriesTitle
        self.nzbURL = nzbURL
        self.discoverStreamIndex = discoverStreamIndex
        self.discoverSourceTitle = discoverSourceTitle
        self.searchQuery = searchQuery
        self.guid = guid
        self.sizeText = sizeText
        self.files = files
        self.grabs = grabs
        self.date = date
        self.poster = poster
        self.backdrop = backdrop
        self.seriesPoster = seriesPoster
        self.seasonPoster = seasonPoster
        self.episodeStill = episodeStill
        self.streamURL = streamURL
        self.progressPercent = progressPercent
        self.viewOffset = viewOffset
        self.viewOffsetSeconds = viewOffsetSeconds
        self.duration = duration
        self.durationSeconds = durationSeconds
        self.durationDisplay = durationDisplay
        self.leafCount = leafCount
        self.seasonCount = seasonCount
        self.episodeCount = episodeCount
        self.resumeTitle = resumeTitle
        self.resumeItem = resumeItem
        self.demoArtworkName = demoArtworkName
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case key
        case ratingKey
        case partKey
        case title
        case type
        case subtitle
        case summary
        case overview
        case description
        case tagline
        case contentRating
        case communityRating
        case mediaType
        case category
        case categoryID = "categoryId"
        case sourceIndex
        case path
        case playStateID = "playStateId"
        case seriesStateID = "seriesStateId"
        case seriesTitle
        case nzbURL = "nzbUrl"
        case discoverStreamIndex
        case discoverSourceTitle
        case searchQuery
        case guid
        case sizeText
        case files
        case grabs
        case date
        case poster
        case backdrop
        case seriesPoster
        case seasonPoster
        case episodeStill
        case streamURL = "streamUrl"
        case progressPercent
        case viewOffset
        case viewOffsetSeconds
        case duration
        case durationSeconds
        case durationDisplay
        case leafCount
        case seasonCount
        case episodeCount
        case resumeTitle
        case resumeItem
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        title = try values.decode(String.self, forKey: .title)
        type = try values.decodeIfPresent(String.self, forKey: .type)
        mediaType = try values.decodeIfPresent(String.self, forKey: .mediaType)
        category = try values.decodeIfPresent(String.self, forKey: .category)
        categoryID = try values.decodeIfPresent(String.self, forKey: .categoryID)
        sourceIndex = try values.decodeIfPresent(Int.self, forKey: .sourceIndex) ?? 0
        path = try values.decodeIfPresent(String.self, forKey: .path)
        playStateID = try values.decodeFlexibleStringIfPresent(forKey: .playStateID)
        seriesStateID = try values.decodeFlexibleStringIfPresent(forKey: .seriesStateID)
        seriesTitle = try values.decodeIfPresent(String.self, forKey: .seriesTitle)
        nzbURL = try values.decodeIfPresent(String.self, forKey: .nzbURL)
        discoverStreamIndex = try values.decodeIfPresent(Int.self, forKey: .discoverStreamIndex) ?? 0
        discoverSourceTitle = try values.decodeIfPresent(String.self, forKey: .discoverSourceTitle)
        searchQuery = try values.decodeIfPresent(String.self, forKey: .searchQuery)
        guid = try values.decodeFlexibleStringIfPresent(forKey: .guid)
        sizeText = try values.decodeIfPresent(String.self, forKey: .sizeText)
        files = try values.decodeFlexibleStringIfPresent(forKey: .files)
        grabs = try values.decodeFlexibleStringIfPresent(forKey: .grabs)
        poster = try values.decodeIfPresent(String.self, forKey: .poster)
        backdrop = try values.decodeIfPresent(String.self, forKey: .backdrop)
        seriesPoster = try values.decodeIfPresent(String.self, forKey: .seriesPoster)
        seasonPoster = try values.decodeIfPresent(String.self, forKey: .seasonPoster)
        episodeStill = try values.decodeIfPresent(String.self, forKey: .episodeStill)
        streamURL = try values.decodeIfPresent(String.self, forKey: .streamURL)
        subtitle = try values.decodeIfPresent(String.self, forKey: .subtitle)
        summary = try values.decodeIfPresent(String.self, forKey: .summary)
            ?? values.decodeIfPresent(String.self, forKey: .overview)
            ?? values.decodeIfPresent(String.self, forKey: .description)
        tagline = try values.decodeIfPresent(String.self, forKey: .tagline)
        contentRating = try values.decodeIfPresent(String.self, forKey: .contentRating)
        communityRating = try values.decodeIfPresent(Double.self, forKey: .communityRating)
        date = try values.decodeIfPresent(String.self, forKey: .date)
        progressPercent = try values.decodeIfPresent(Double.self, forKey: .progressPercent)
        viewOffset = try values.decodeFlexibleInt64IfPresent(forKey: .viewOffset)
        viewOffsetSeconds = try values.decodeIfPresent(Double.self, forKey: .viewOffsetSeconds)
        duration = try values.decodeFlexibleInt64IfPresent(forKey: .duration)
        durationSeconds = try values.decodeIfPresent(Double.self, forKey: .durationSeconds)
        durationDisplay = try values.decodeIfPresent(String.self, forKey: .durationDisplay)
        leafCount = try values.decodeIfPresent(Int.self, forKey: .leafCount) ?? 0
        seasonCount = try values.decodeIfPresent(Int.self, forKey: .seasonCount) ?? 0
        episodeCount = try values.decodeIfPresent(Int.self, forKey: .episodeCount) ?? 0
        resumeTitle = try values.decodeIfPresent(String.self, forKey: .resumeTitle)
        resumeItem = try values.decodeIfPresent(ResumeMediaItem.self, forKey: .resumeItem)
        demoArtworkName = nil
        id = try values.decodeFlexibleStringIfPresent(forKey: .id)
            ?? values.decodeFlexibleStringIfPresent(forKey: .playStateID)
            ?? values.decodeFlexibleStringIfPresent(forKey: .ratingKey)
            ?? values.decodeFlexibleStringIfPresent(forKey: .partKey)
            ?? values.decodeFlexibleStringIfPresent(forKey: .key)
            ?? guid
            ?? path
            ?? streamURL
            ?? nzbURL
            ?? [mediaType, title, date].compactMap { $0 }.joined(separator: ":")
    }
}

struct ResumeMediaItem: Decodable, Equatable {
    let id: String
    let title: String
    let type: String?
    let summary: String?
    let mediaType: String?
    let categoryID: String?
    let sourceIndex: Int
    let path: String?
    let playStateID: String?
    let seriesStateID: String?
    let seriesTitle: String?
    let poster: String?
    let backdrop: String?
    let seriesPoster: String?
    let seasonPoster: String?
    let episodeStill: String?
    let streamURL: String?
    let progressPercent: Double?
    let viewOffset: Int64?
    let viewOffsetSeconds: Double?
    let duration: Int64?
    let durationSeconds: Double?
    let durationDisplay: String?

    private enum CodingKeys: String, CodingKey {
        case id, key, ratingKey, partKey, title, type, summary, overview, description
        case mediaType, categoryID = "categoryId", sourceIndex, path
        case playStateID = "playStateId", seriesStateID = "seriesStateId", seriesTitle
        case poster, backdrop, seriesPoster, seasonPoster, episodeStill
        case streamURL = "streamUrl", progressPercent, viewOffset, viewOffsetSeconds
        case duration, durationSeconds, durationDisplay
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        title = try values.decode(String.self, forKey: .title)
        type = try values.decodeIfPresent(String.self, forKey: .type)
        mediaType = try values.decodeIfPresent(String.self, forKey: .mediaType)
        categoryID = try values.decodeIfPresent(String.self, forKey: .categoryID)
        sourceIndex = try values.decodeIfPresent(Int.self, forKey: .sourceIndex) ?? 0
        path = try values.decodeIfPresent(String.self, forKey: .path)
        playStateID = try values.decodeFlexibleStringIfPresent(forKey: .playStateID)
        seriesStateID = try values.decodeFlexibleStringIfPresent(forKey: .seriesStateID)
        seriesTitle = try values.decodeIfPresent(String.self, forKey: .seriesTitle)
        poster = try values.decodeIfPresent(String.self, forKey: .poster)
        backdrop = try values.decodeIfPresent(String.self, forKey: .backdrop)
        seriesPoster = try values.decodeIfPresent(String.self, forKey: .seriesPoster)
        seasonPoster = try values.decodeIfPresent(String.self, forKey: .seasonPoster)
        episodeStill = try values.decodeIfPresent(String.self, forKey: .episodeStill)
        streamURL = try values.decodeIfPresent(String.self, forKey: .streamURL)
        summary = try values.decodeIfPresent(String.self, forKey: .summary)
            ?? values.decodeIfPresent(String.self, forKey: .overview)
            ?? values.decodeIfPresent(String.self, forKey: .description)
        progressPercent = try values.decodeIfPresent(Double.self, forKey: .progressPercent)
        viewOffset = try values.decodeFlexibleInt64IfPresent(forKey: .viewOffset)
        viewOffsetSeconds = try values.decodeIfPresent(Double.self, forKey: .viewOffsetSeconds)
        duration = try values.decodeFlexibleInt64IfPresent(forKey: .duration)
        durationSeconds = try values.decodeIfPresent(Double.self, forKey: .durationSeconds)
        durationDisplay = try values.decodeIfPresent(String.self, forKey: .durationDisplay)
        id = try values.decodeFlexibleStringIfPresent(forKey: .id)
            ?? values.decodeFlexibleStringIfPresent(forKey: .playStateID)
            ?? values.decodeFlexibleStringIfPresent(forKey: .ratingKey)
            ?? values.decodeFlexibleStringIfPresent(forKey: .partKey)
            ?? values.decodeFlexibleStringIfPresent(forKey: .key)
            ?? path
            ?? [mediaType, title].compactMap { $0 }.joined(separator: ":")
    }

    var mediaItem: MediaItem {
        MediaItem(
            id: id,
            title: title,
            type: type,
            summary: summary,
            mediaType: mediaType,
            categoryID: categoryID,
            sourceIndex: sourceIndex,
            path: path,
            playStateID: playStateID,
            seriesStateID: seriesStateID,
            seriesTitle: seriesTitle,
            poster: poster,
            backdrop: backdrop,
            seriesPoster: seriesPoster,
            seasonPoster: seasonPoster,
            episodeStill: episodeStill,
            streamURL: streamURL,
            progressPercent: progressPercent,
            viewOffset: viewOffset,
            viewOffsetSeconds: viewOffsetSeconds,
            duration: duration,
            durationSeconds: durationSeconds,
            durationDisplay: durationDisplay
        )
    }
}

struct PlaybackPlan: Decodable, Equatable {
    let streamURL: String
    let mode: String
    let videoMode: String
    let audioMode: String
    let videoCodec: String?
    let audioCodec: String?
    let qualityLabel: String
    let reason: String?
    let resolutionLabel: String?
    let outputContainer: String?
    let selectedAudioTrack: Int
    let source: PlaybackMediaInfo

    private enum CodingKeys: String, CodingKey {
        case streamURL = "streamUrl"
        case mode
        case videoMode
        case audioMode
        case videoCodec
        case audioCodec
        case qualityLabel
        case reason
        case resolutionLabel
        case outputContainer
        case selectedAudioTrack
        case source
    }
}

struct PlaybackMediaInfo: Decodable, Equatable {
    let container: String?
    let videoCodec: String?
    let width: Int?
    let height: Int?
    let videoRange: String?
    let audioCodec: String?
    let audioChannels: Int?
    let audioTracks: [PlaybackAudioTrack]?
}

struct PlaybackAudioTrack: Decodable, Equatable, Identifiable {
    var id: Int { index }
    let index: Int
    let streamIndex: Int?
    let codec: String?
    let channels: Int?
    let language: String?
    let title: String?
    let isDefault: Bool?
    let commentary: Bool?
    let descriptive: Bool?

    private enum CodingKeys: String, CodingKey {
        case index
        case streamIndex
        case codec
        case channels
        case language
        case title
        case isDefault = "default"
        case commentary
        case descriptive
    }
}

struct NextEpisodeResponse: Decodable {
    let item: MediaItem?
}

struct TubeTVGuide: Decodable {
    let channels: [LiveChannel]
    let startedAt: String?
    let plannedUntil: String?
    let serverNow: String?
    let settings: TubeTVSettings?
    let receivedAt: Date

    init(
        channels: [LiveChannel],
        startedAt: String? = nil,
        plannedUntil: String? = nil,
        serverNow: String? = nil,
        settings: TubeTVSettings? = nil,
        receivedAt: Date = Date()
    ) {
        self.channels = channels
        self.startedAt = startedAt
        self.plannedUntil = plannedUntil
        self.serverNow = serverNow
        self.settings = settings
        self.receivedAt = receivedAt
    }

    private enum CodingKeys: String, CodingKey {
        case channels, startedAt, plannedUntil, serverNow, settings
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        channels = try values.decodeIfPresent([LiveChannel].self, forKey: .channels) ?? []
        startedAt = try values.decodeIfPresent(String.self, forKey: .startedAt)
        plannedUntil = try values.decodeIfPresent(String.self, forKey: .plannedUntil)
        serverNow = try values.decodeIfPresent(String.self, forKey: .serverNow)
        settings = try values.decodeIfPresent(TubeTVSettings.self, forKey: .settings)
        receivedAt = Date()
    }

    func elapsedSeconds(at date: Date = Date()) -> Double {
        guard let started = Self.parseServerDate(startedAt) else { return 0 }
        let serverReference = Self.parseServerDate(serverNow) ?? receivedAt
        return max(0, serverReference.timeIntervalSince(started) + date.timeIntervalSince(receivedAt))
    }

    func startDate(for program: LiveProgram) -> Date? {
        guard let started = Self.parseServerDate(startedAt) else { return nil }
        return started.addingTimeInterval(program.start)
    }

    private static func parseServerDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }
        return ISO8601DateFormatter().date(from: value)
    }
}

struct TubeTVSettings: Decodable {
    let enabled: Bool?
    let autoChannels: Bool?
    let commercialsEnabled: Bool?
    let midrollCommercials: Bool?
    let commercialCategories: [String]?
}

struct LiveChannel: Decodable, Equatable, Identifiable {
    let id: String
    let number: String
    let title: String
    let logoPath: String?
    let logoURL: String?
    let logoTitle: String?
    let logoPosition: String?
    let autoGenerated: Bool
    let streamURL: String?
    let now: LiveProgram?
    let next: LiveProgram?
    let schedule: [LiveProgram]
    let totalDuration: Double

    private enum CodingKeys: String, CodingKey {
        case id
        case number
        case title
        case logoPath
        case logoURL = "logoUrl"
        case logoTitle
        case logoPosition
        case autoGenerated
        case streamURL = "streamUrl"
        case now
        case next
        case schedule
        case totalDuration
    }

    init(
        id: String? = nil,
        number: String,
        title: String,
        logoPath: String? = nil,
        logoURL: String? = nil,
        logoTitle: String? = nil,
        logoPosition: String? = nil,
        autoGenerated: Bool = false,
        streamURL: String? = nil,
        now: LiveProgram? = nil,
        next: LiveProgram? = nil,
        schedule: [LiveProgram] = [],
        totalDuration: Double = 0
    ) {
        self.id = id ?? [number, title].joined(separator: ":")
        self.number = number
        self.title = title
        self.logoPath = logoPath
        self.logoURL = logoURL
        self.logoTitle = logoTitle
        self.logoPosition = logoPosition
        self.autoGenerated = autoGenerated
        self.streamURL = streamURL
        self.now = now
        self.next = next
        self.schedule = schedule
        self.totalDuration = totalDuration
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        number = try values.decodeIfPresent(String.self, forKey: .number) ?? ""
        title = try values.decode(String.self, forKey: .title)
        logoPath = try values.decodeIfPresent(String.self, forKey: .logoPath)
        logoURL = try values.decodeIfPresent(String.self, forKey: .logoURL)
        logoTitle = try values.decodeIfPresent(String.self, forKey: .logoTitle)
        logoPosition = try values.decodeIfPresent(String.self, forKey: .logoPosition)
        autoGenerated = try values.decodeIfPresent(Bool.self, forKey: .autoGenerated) ?? false
        streamURL = try values.decodeIfPresent(String.self, forKey: .streamURL)
        now = try values.decodeIfPresent(LiveProgram.self, forKey: .now)
        next = try values.decodeIfPresent(LiveProgram.self, forKey: .next)
        schedule = try values.decodeIfPresent([LiveProgram].self, forKey: .schedule) ?? []
        totalDuration = try values.decodeIfPresent(Double.self, forKey: .totalDuration) ?? 0
        id = try values.decodeFlexibleStringIfPresent(forKey: .id)
            ?? [number, title].joined(separator: ":")
    }

    var playbackItem: MediaItem {
        MediaItem(
            id: "tube-tv:\(number)",
            title: title,
            subtitle: number.isEmpty ? "Live on Tater Tube" : "Channel \(number)",
            summary: now.map { "Now playing: \($0.title)" },
            mediaType: "channel",
            poster: logoURL,
            streamURL: streamURL
        )
    }

    func displayedPrograms(elapsed: Double) -> [LiveProgram] {
        guard !schedule.isEmpty else {
            var fallback: [LiveProgram] = []
            if let now {
                fallback.append(now.isInterstitial
                    ? LiveProgram(
                        title: "Commercial Break",
                        kind: "commercial_break",
                        mediaType: "commercial_break",
                        start: now.start,
                        end: now.end,
                        duration: now.duration,
                        progressPercent: now.progressPercent,
                        isCommercialBreak: true
                    )
                    : now)
            }
            if let next, !next.isInterstitial { fallback.append(next) }
            return fallback
        }

        var programs: [LiveProgram] = []
        var firstFutureIndex = schedule.endIndex
        if let currentIndex = schedule.firstIndex(where: { $0.start <= elapsed && elapsed < $0.end }) {
            let current = schedule[currentIndex]
            programs.append(current.isInterstitial
                ? LiveProgram.commercialBreak(in: schedule, around: currentIndex)
                : current)
            firstFutureIndex = schedule.index(after: currentIndex)
        } else if let future = schedule.firstIndex(where: { $0.start > elapsed }) {
            firstFutureIndex = future
        }

        for program in schedule[firstFutureIndex...] where programs.count < 3 {
            if !program.isInterstitial { programs.append(program) }
        }
        return programs
    }
}

struct LiveProgram: Decodable, Equatable, Identifiable {
    let id: String
    let title: String
    let kind: String?
    let mediaType: String?
    let category: String?
    let categoryID: String?
    let sourceIndex: Int
    let path: String?
    let streamURL: String?
    let summary: String?
    let start: Double
    let end: Double
    let duration: Double
    let progressPercent: Double?
    let poster: String?
    let backdrop: String?
    let seriesPoster: String?
    let seasonPoster: String?
    let episodeStill: String?
    let isCommercialBreak: Bool
    let demoArtworkName: String?

    init(
        id: String? = nil,
        title: String,
        kind: String? = nil,
        mediaType: String? = nil,
        category: String? = nil,
        categoryID: String? = nil,
        sourceIndex: Int = 0,
        path: String? = nil,
        streamURL: String? = nil,
        summary: String? = nil,
        start: Double = 0,
        end: Double = 0,
        duration: Double = 0,
        progressPercent: Double? = nil,
        poster: String? = nil,
        backdrop: String? = nil,
        seriesPoster: String? = nil,
        seasonPoster: String? = nil,
        episodeStill: String? = nil,
        isCommercialBreak: Bool = false,
        demoArtworkName: String? = nil
    ) {
        self.id = id ?? [kind, title, String(start), String(end)].compactMap { $0 }.joined(separator: ":")
        self.title = title
        self.kind = kind
        self.mediaType = mediaType
        self.category = category
        self.categoryID = categoryID
        self.sourceIndex = sourceIndex
        self.path = path
        self.streamURL = streamURL
        self.summary = summary
        self.start = start
        self.end = end
        self.duration = duration
        self.progressPercent = progressPercent
        self.poster = poster
        self.backdrop = backdrop
        self.seriesPoster = seriesPoster
        self.seasonPoster = seasonPoster
        self.episodeStill = episodeStill
        self.isCommercialBreak = isCommercialBreak
        self.demoArtworkName = demoArtworkName
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, kind, mediaType, category, categoryID = "categoryId", sourceIndex
        case path, streamURL = "streamUrl", summary, description, start, end, duration
        case progressPercent, poster, backdrop, seriesPoster, seasonPoster, episodeStill
        case isCommercialBreak
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        title = try values.decodeIfPresent(String.self, forKey: .title) ?? "Tater Tube"
        kind = try values.decodeIfPresent(String.self, forKey: .kind)
        mediaType = try values.decodeIfPresent(String.self, forKey: .mediaType)
        category = try values.decodeIfPresent(String.self, forKey: .category)
        categoryID = try values.decodeIfPresent(String.self, forKey: .categoryID)
        sourceIndex = try values.decodeIfPresent(Int.self, forKey: .sourceIndex) ?? 0
        path = try values.decodeIfPresent(String.self, forKey: .path)
        streamURL = try values.decodeIfPresent(String.self, forKey: .streamURL)
        summary = try values.decodeIfPresent(String.self, forKey: .summary)
            ?? values.decodeIfPresent(String.self, forKey: .description)
        start = try values.decodeFlexibleDoubleIfPresent(forKey: .start) ?? 0
        end = try values.decodeFlexibleDoubleIfPresent(forKey: .end) ?? 0
        duration = try values.decodeFlexibleDoubleIfPresent(forKey: .duration) ?? max(0, end - start)
        progressPercent = try values.decodeFlexibleDoubleIfPresent(forKey: .progressPercent)
        poster = try values.decodeIfPresent(String.self, forKey: .poster)
        backdrop = try values.decodeIfPresent(String.self, forKey: .backdrop)
        seriesPoster = try values.decodeIfPresent(String.self, forKey: .seriesPoster)
        seasonPoster = try values.decodeIfPresent(String.self, forKey: .seasonPoster)
        episodeStill = try values.decodeIfPresent(String.self, forKey: .episodeStill)
        isCommercialBreak = try values.decodeIfPresent(Bool.self, forKey: .isCommercialBreak) ?? false
        demoArtworkName = nil
        id = try values.decodeFlexibleStringIfPresent(forKey: .id)
            ?? [kind, title, String(start), String(end)].compactMap { $0 }.joined(separator: ":")
    }

    var isInterstitial: Bool {
        ["commercial", "bumper", "tater_bumper", "commercial_break"]
            .contains((kind ?? mediaType ?? "").lowercased())
    }

    var artworkValue: String? {
        [backdrop, episodeStill, poster, seriesPoster, seasonPoster]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
            .first
    }

    func progress(at elapsed: Double) -> Double {
        guard end > start else { return min(max((progressPercent ?? 0) / 100, 0), 1) }
        return min(max((elapsed - start) / (end - start), 0), 1)
    }

    static func commercialBreak(in schedule: [LiveProgram], around index: Int) -> LiveProgram {
        var first = index
        var last = index
        while first > schedule.startIndex, schedule[first - 1].isInterstitial { first -= 1 }
        while last + 1 < schedule.endIndex, schedule[last + 1].isInterstitial { last += 1 }
        return LiveProgram(
            title: "Commercial Break",
            kind: "commercial_break",
            mediaType: "commercial_break",
            start: schedule[first].start,
            end: schedule[last].end,
            duration: max(0, schedule[last].end - schedule[first].start),
            isCommercialBreak: true
        )
    }
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

    func decodeFlexibleDoubleIfPresent(forKey key: Key) throws -> Double? {
        if let number = try? decodeIfPresent(Double.self, forKey: key) {
            return number
        }
        if let integer = try? decodeIfPresent(Int64.self, forKey: key) {
            return Double(integer)
        }
        if let string = try? decodeIfPresent(String.self, forKey: key) {
            return Double(string)
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

    static let libraryRows: [LibraryRow] = [
        LibraryRow(
            title: "Continue Watching",
            entry: LibraryEntry(id: "", title: "Continue Watching", type: "continue"),
            items: home.continueWatching
        ),
        LibraryRow(
            title: "Recently Added",
            entry: LibraryEntry(id: "local-discover:recent", title: "Recently Added", type: "localDiscover"),
            items: home.recentlyAdded
        ),
        LibraryRow(
            title: "Movies",
            entry: LibraryEntry(id: "local-discover:movies", title: "Movies", type: "localDiscover"),
            items: demoMovies
        ),
        LibraryRow(
            title: "Series",
            entry: LibraryEntry(id: "local-discover:series", title: "Series", type: "localDiscover"),
            items: demoShows
        )
    ]

    static func libraryPage(for location: LibraryLocation) -> LibraryPage {
        if location.continueWatching {
            return LibraryPage(title: "Continue Watching", items: home.continueWatching)
        }
        switch location.categoryID {
        case "local-discover:movies":
            return LibraryPage(title: "All Movies", items: demoMovies)
        case "local-discover:series":
            return LibraryPage(title: "All TV Shows", items: demoShows)
        default:
            break
        }

        switch location.path {
        case "Harbor Street":
            return LibraryPage(title: "Harbor Street", items: demoSeasons)
        case "Harbor Street/Season 1":
            return LibraryPage(title: "Season 1", items: demoEpisodes(season: 1))
        case "Harbor Street/Season 2":
            return LibraryPage(title: "Season 2", items: demoEpisodes(season: 2))
        default:
            return LibraryPage(title: location.title, items: home.recentlyAdded)
        }
    }

    static let discoveryCategories: [DiscoverCategory] = {
        let year = Calendar.current.component(.year, from: Date())
        return [
            DiscoverCategory(id: "movie:top", title: "Popular Movies", detail: "The movies people are watching now", category: "movie"),
            DiscoverCategory(id: "movie:year:\(year)", title: "New Movies", detail: "Fresh releases from \(year)", category: "movie"),
            DiscoverCategory(id: "movie:imdbrating", title: "Featured Movies", detail: "Highly rated movie picks", category: "movie"),
            DiscoverCategory(id: "series:top", title: "Popular TV", detail: "Series everyone is talking about", category: "series"),
            DiscoverCategory(id: "series:year:\(year)", title: "New TV", detail: "New series from \(year)", category: "series"),
            DiscoverCategory(id: "series:imdbrating", title: "Featured TV", detail: "Highly rated shows to discover", category: "series")
        ]
    }()

    static func discoveryPage(for category: DiscoverCategory) -> LibraryPage {
        let isSeries = category.id.lowercased().hasPrefix("series:")
        let base = isSeries ? demoShows : demoMovies
        let repeated = base + Array(base.reversed())
        let items = repeated.enumerated().map { index, item in
            MediaItem(
                id: "discover-title:\(category.id):\(index):\(item.id)",
                title: item.title,
                type: "discover",
                subtitle: item.date,
                summary: item.summary,
                mediaType: isSeries ? "series" : "movie",
                category: isSeries ? "TV" : "Movies",
                categoryID: "discover",
                discoverSourceTitle: item.title,
                searchQuery: item.title,
                date: item.date,
                poster: item.poster,
                backdrop: item.backdrop,
                demoArtworkName: item.demoArtworkName
            )
        }
        return LibraryPage(title: category.title, items: items)
    }

    static func discoverySearchResults(for title: MediaItem) -> LibraryPage {
        let normalized = title.title.replacingOccurrences(of: " ", with: ".")
        let year = title.date ?? "2026"
        let names = [
            "\(normalized).\(year).2160p.WEB-DL.DDP5.1.H.265-TATER",
            "\(normalized).\(year).1080p.BluRay.DTS-HD.MA.5.1-TUBE",
            "\(normalized).\(year).1080p.WEB-DL.AAC2.0.H.264-TOT"
        ]
        return LibraryPage(
            title: "Choose a release",
            items: names.enumerated().map { index, name in
                MediaItem(
                    id: "demo-release:\(title.id):\(index)",
                    title: name,
                    type: "release",
                    subtitle: index == 0 ? "14.8 GB" : (index == 1 ? "8.2 GB" : "4.6 GB"),
                    summary: title.summary,
                    mediaType: title.mediaType,
                    category: index == 1 ? "Movies > HD" : "Movies > UHD",
                    categoryID: "discover",
                    nzbURL: "https://demo.invalid/\(index).nzb",
                    discoverSourceTitle: title.title,
                    searchQuery: title.searchQuery,
                    sizeText: index == 0 ? "14.8 GB" : (index == 1 ? "8.2 GB" : "4.6 GB"),
                    files: index == 2 ? "1 file" : "3 files",
                    grabs: index == 0 ? "248 grabs" : "96 grabs",
                    date: title.date,
                    poster: title.poster,
                    backdrop: title.backdrop,
                    demoArtworkName: title.demoArtworkName
                )
            }
        )
    }

    private static let demoMovies = [
        MediaItem(id: "demo-movie-cosmic", title: "Cosmic Drift", summary: "A lone explorer follows an impossible signal beyond the mapped stars.", mediaType: "movie", categoryID: "local:movies", path: "Cosmic Drift (2026)/Cosmic Drift.mkv", date: "2026", progressPercent: 38, demoArtworkName: "cosmic-drift-poster"),
        MediaItem(id: "demo-movie-winter", title: "The Long Winter", summary: "A final supply run becomes a race across a frozen frontier.", mediaType: "movie", categoryID: "local:movies", path: "The Long Winter (2025)/The Long Winter.mkv", date: "2025", demoArtworkName: "the-long-winter"),
        MediaItem(id: "demo-movie-neon", title: "Neon Nights", summary: "A midnight drive through a city that never quite sleeps.", mediaType: "movie", categoryID: "local:movies", path: "Neon Nights (2026)/Neon Nights.mkv", date: "2026", demoArtworkName: "neon-nights"),
        MediaItem(id: "demo-movie-orange", title: "Orange County Skies", summary: "One last coastal drive changes the road ahead.", mediaType: "movie", categoryID: "local:movies", path: "Orange County Skies (2025)/Orange County Skies.mkv", date: "2025", demoArtworkName: "orange-county-skies")
    ]

    private static let demoShows = [
        MediaItem(id: "demo-show-harbor", title: "Harbor Street", summary: "A close-knit harbor town finds a new beginning after the storm.", mediaType: "show", categoryID: "local:tv", path: "Harbor Street", date: "2024", seasonCount: 2, episodeCount: 16, demoArtworkName: "harbor-street"),
        MediaItem(id: "demo-show-north", title: "Northern Lights", summary: "Two old friends return north and uncover what the quiet kept hidden.", mediaType: "show", categoryID: "local:tv", path: "Northern Lights", date: "2024", seasonCount: 3, episodeCount: 24, demoArtworkName: "northern-lights"),
        MediaItem(id: "demo-show-midnight", title: "After Midnight", summary: "A late-night radio signal carries secrets from across the valley.", mediaType: "show", categoryID: "local:tv", path: "After Midnight", date: "2023", seasonCount: 1, episodeCount: 8, demoArtworkName: "after-midnight")
    ]

    private static let demoSeasons = [
        MediaItem(id: "demo-harbor-s1", title: "Season 1", mediaType: "season", categoryID: "local:tv", path: "Harbor Street/Season 1", episodeCount: 8, demoArtworkName: "harbor-street"),
        MediaItem(id: "demo-harbor-s2", title: "Season 2", mediaType: "season", categoryID: "local:tv", path: "Harbor Street/Season 2", progressPercent: 46, episodeCount: 8, resumeTitle: "S02E04 Safe Harbor", demoArtworkName: "harbor-street")
    ]

    private static func demoEpisodes(season: Int) -> [MediaItem] {
        (1...8).map { episode in
            let watched = season == 2 && episode < 4
            let current = season == 2 && episode == 4
            return MediaItem(
                id: "demo-harbor-s\(season)e\(episode)",
                title: String(format: "S%02dE%02d %@", season, episode, episodeTitles[(episode - 1) % episodeTitles.count]),
                summary: "The harbor crew follows a new lead while the tide changes around them.",
                mediaType: "episode",
                categoryID: "local:tv",
                path: String(format: "Harbor Street/Season %d/Harbor Street S%02dE%02d.mkv", season, season, episode),
                seriesStateID: "demo-harbor-series",
                seriesTitle: "Harbor Street",
                progressPercent: current ? 46 : (watched ? 100 : nil),
                viewOffsetSeconds: current ? 1240 : nil,
                durationSeconds: 2700,
                durationDisplay: "45 min",
                demoArtworkName: "harbor-street"
            )
        }
    }

    private static let episodeTitles = [
        "Low Tide", "The Lantern", "Old Maps", "Safe Harbor",
        "North Wind", "Night Watch", "The Crossing", "Home Water"
    ]

    static let liveGuide = TubeTVGuide(channels: [
        LiveChannel(
            number: "07",
            title: "Sci-Fi Movies",
            logoTitle: "SCI-FI MOVIES",
            autoGenerated: true,
            schedule: [
                LiveProgram(title: "Cosmic Drift", kind: "movie", mediaType: "movie", start: 0, end: 4200, duration: 4200, demoArtworkName: "cosmic-drift-poster"),
                LiveProgram(title: "Station Break", kind: "commercial", start: 4200, end: 4260, duration: 60),
                LiveProgram(title: "Neon Nights", kind: "movie", mediaType: "movie", start: 4260, end: 8460, duration: 4200, demoArtworkName: "neon-nights"),
                LiveProgram(title: "The Long Winter", kind: "movie", mediaType: "movie", start: 8460, end: 12660, duration: 4200, demoArtworkName: "the-long-winter")
            ]
        ),
        LiveChannel(
            number: "12",
            title: "Saturday Cartoons",
            logoTitle: "SATURDAY CARTOONS",
            schedule: [
                LiveProgram(title: "Commercial Break", kind: "commercial", start: 0, end: 95, duration: 95),
                LiveProgram(title: "Harbor Street", kind: "episode", mediaType: "episode", start: 95, end: 2795, duration: 2700, demoArtworkName: "harbor-street"),
                LiveProgram(title: "Northern Lights", kind: "episode", mediaType: "episode", start: 2795, end: 5495, duration: 2700, demoArtworkName: "northern-lights"),
                LiveProgram(title: "After Midnight", kind: "episode", mediaType: "episode", start: 5495, end: 8195, duration: 2700, demoArtworkName: "after-midnight")
            ]
        ),
        LiveChannel(
            number: "24",
            title: "Creature Features",
            logoTitle: "CREATURE FEATURES",
            autoGenerated: true,
            schedule: [
                LiveProgram(title: "After Midnight", kind: "movie", mediaType: "movie", start: 0, end: 4800, duration: 4800, demoArtworkName: "after-midnight"),
                LiveProgram(title: "The Long Winter", kind: "movie", mediaType: "movie", start: 4800, end: 9600, duration: 4800, demoArtworkName: "the-long-winter"),
                LiveProgram(title: "Orange County Skies", kind: "movie", mediaType: "movie", start: 9600, end: 14400, duration: 4800, demoArtworkName: "orange-county-skies")
            ]
        ),
        LiveChannel(
            number: "88",
            title: "Neon Nights",
            logoTitle: "NEON NIGHTS",
            schedule: [
                LiveProgram(title: "Neon Nights", kind: "movie", mediaType: "movie", start: 0, end: 4500, duration: 4500, demoArtworkName: "neon-nights"),
                LiveProgram(title: "Orange County Skies", kind: "movie", mediaType: "movie", start: 4500, end: 9000, duration: 4500, demoArtworkName: "orange-county-skies"),
                LiveProgram(title: "Cosmic Drift", kind: "movie", mediaType: "movie", start: 9000, end: 13500, duration: 4500, demoArtworkName: "cosmic-drift-poster")
            ]
        )
    ])
}
