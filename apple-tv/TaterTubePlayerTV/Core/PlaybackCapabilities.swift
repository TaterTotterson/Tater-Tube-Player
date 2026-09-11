import AVFoundation
import UIKit
import VideoToolbox

struct PlaybackCapabilitiesReport: Encodable {
    let capabilityVersion = 3
    let platform = "tvos"
    let engine = "avkit"
    let outputName = UIDevice.current.name
    let outputConnection = "hdmi"
    let containers = ["mp4", "mpegts", "hls"]
    let videoCodecs: [String]
    // Keep this list to codecs AVPlayer can reliably consume in either MP4 or
    // the MPEG-TS stream requested from Tater Tube Server.
    let audioCodecs = ["aac", "ac3", "eac3"]
    let audioPassthrough: [String] = []
    let passthroughAvailable = false
    let audioDownmix = true
    let videoHDRFormats: [String]
    let displayHDRFormats: [String]
    let displayHDREnabled: Bool
    let maxVideoBitDepth: Int
    let dolbyVisionProfiles: [Int] = []
    let maxWidth: Int
    let maxHeight: Int
    let maxAudioChannels: Int
    let compatibilityMode = true
    let preferredStreamContainer = "mpegts"

    static var current: PlaybackCapabilitiesReport {
        let bounds = UIScreen.main.nativeBounds
        let width = max(Int(bounds.width), Int(bounds.height))
        let height = min(Int(bounds.width), Int(bounds.height))

        var codecs = ["h264"]
        if VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC) {
            codecs.append("hevc")
        }

        let modes = AVPlayer.availableHDRModes
        var ranges: [String] = []
        if modes.contains(.hdr10) { ranges.append("hdr10") }
        if modes.contains(.hlg) { ranges.append("hlg") }
        if modes.contains(.dolbyVision) { ranges.append("dolby_vision") }

        let channels = max(2, AVAudioSession.sharedInstance().maximumOutputNumberOfChannels)
        return PlaybackCapabilitiesReport(
            videoCodecs: codecs,
            videoHDRFormats: ranges,
            displayHDRFormats: ranges,
            displayHDREnabled: !ranges.isEmpty,
            maxVideoBitDepth: ranges.isEmpty ? 8 : 10,
            maxWidth: width > 0 ? width : 1920,
            maxHeight: height > 0 ? height : 1080,
            maxAudioChannels: channels
        )
    }

    var profile: String {
        if maxWidth >= 3840 && maxHeight >= 2160 { return "hdmi_4k" }
        if maxWidth >= 1920 && maxHeight >= 1080 { return "hdmi_1080p" }
        return "hdmi_720p"
    }

    private enum CodingKeys: String, CodingKey {
        case capabilityVersion = "capability_version"
        case platform
        case engine
        case outputName = "output_name"
        case outputConnection = "output_connection"
        case containers
        case videoCodecs = "video_codecs"
        case audioCodecs = "audio_codecs"
        case audioPassthrough = "audio_passthrough"
        case passthroughAvailable = "passthrough_available"
        case audioDownmix = "audio_downmix"
        case videoHDRFormats = "video_hdr_formats"
        case displayHDRFormats = "display_hdr_formats"
        case displayHDREnabled = "display_hdr_enabled"
        case maxVideoBitDepth = "max_video_bit_depth"
        case dolbyVisionProfiles = "dolby_vision_profiles"
        case maxWidth = "max_width"
        case maxHeight = "max_height"
        case maxAudioChannels = "max_audio_channels"
        case compatibilityMode = "compatibility_mode"
        case preferredStreamContainer = "preferred_stream_container"
    }
}

struct PlaybackSessionRequest: Encodable {
    let streamURL: String
    let mediaType: String
    let profile: String
    let capabilities: PlaybackCapabilitiesReport
    let audioTrack: Int?

    private enum CodingKeys: String, CodingKey {
        case streamURL = "stream_url"
        case mediaType = "media_type"
        case profile
        case capabilities
        case audioTrack = "audio_track"
    }
}

struct PlayStateRequest: Encodable {
    let id: String?
    let seriesID: String?
    let title: String
    let seriesTitle: String?
    let mediaType: String?
    let category: String?
    let categoryID: String?
    let sourceIndex: Int
    let path: String?
    let nzbURL: String?
    let discoverStreamIndex: Int
    let discoverSourceTitle: String?
    let poster: String?
    let backdrop: String?
    let description: String?
    let date: String?
    let positionMS: Int64
    let durationMS: Int64
    let completed: Bool
    let playbackActive: Bool

    init(item: MediaItem, positionMS: Int64, durationMS: Int64, completed: Bool, playbackActive: Bool) {
        id = item.playStateID
        seriesID = item.seriesStateID
        title = item.title
        seriesTitle = item.seriesTitle
        mediaType = item.mediaType
        category = item.category
        categoryID = item.categoryID
        sourceIndex = item.sourceIndex
        path = item.path
        nzbURL = item.nzbURL
        discoverStreamIndex = item.discoverStreamIndex
        discoverSourceTitle = item.discoverSourceTitle
        poster = item.poster
        backdrop = item.backdrop
        description = item.summary
        date = item.date
        self.positionMS = max(0, positionMS)
        self.durationMS = max(0, durationMS)
        self.completed = completed
        self.playbackActive = playbackActive && !completed
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case seriesID = "seriesId"
        case title
        case seriesTitle
        case mediaType
        case category
        case categoryID = "categoryId"
        case sourceIndex
        case path
        case nzbURL = "nzbUrl"
        case discoverStreamIndex
        case discoverSourceTitle
        case poster
        case backdrop
        case description
        case date
        case positionMS = "positionMs"
        case durationMS = "durationMs"
        case completed
        case playbackActive
    }
}

struct NextEpisodeRequest: Encodable {
    let id: String?
    let seriesID: String?
    let title: String
    let seriesTitle: String?
    let mediaType: String
    let categoryID: String?
    let sourceIndex: Int
    let path: String

    init?(item: MediaItem) {
        guard item.mediaType?.lowercased() == "episode",
              let path = item.path, !path.isEmpty else { return nil }
        id = item.playStateID
        seriesID = item.seriesStateID
        title = item.title
        seriesTitle = item.seriesTitle
        mediaType = "episode"
        categoryID = item.categoryID
        sourceIndex = item.sourceIndex
        self.path = path
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case seriesID = "seriesId"
        case title
        case seriesTitle
        case mediaType
        case categoryID = "categoryId"
        case sourceIndex
        case path
    }
}
