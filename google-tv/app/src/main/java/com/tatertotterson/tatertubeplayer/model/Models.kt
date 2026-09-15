package com.tatertotterson.tatertubeplayer.model

import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

data class PlayerCapabilities(
    val localMedia: Boolean = false,
    val newznab: Boolean = false,
    val tubeTV: Boolean = false,
    val commercials: Boolean = false,
    val taterLink: Boolean = false,
)

data class HomeHero(
    val eyebrow: String = "Everything good, right where you left it",
    val message: String = "Your Tater Tube is ready.",
    val personalized: Boolean = false,
)

data class MediaItem(
    val id: String,
    val title: String,
    val type: String? = null,
    val subtitle: String? = null,
    val summary: String? = null,
    val tagline: String? = null,
    val contentRating: String? = null,
    val communityRating: Double? = null,
    val mediaType: String? = null,
    val category: String? = null,
    val categoryId: String? = null,
    val sourceIndex: Int = 0,
    val path: String? = null,
    val playStateId: String? = null,
    val seriesStateId: String? = null,
    val seriesTitle: String? = null,
    val nzbUrl: String? = null,
    val discoverStreamIndex: Int = 0,
    val discoverSourceTitle: String? = null,
    val searchQuery: String? = null,
    val guid: String? = null,
    val sizeText: String? = null,
    val files: String? = null,
    val grabs: String? = null,
    val date: String? = null,
    val poster: String? = null,
    val backdrop: String? = null,
    val seriesPoster: String? = null,
    val seasonPoster: String? = null,
    val episodeStill: String? = null,
    val streamUrl: String? = null,
    val progressPercent: Double = 0.0,
    val viewOffsetMs: Long = 0,
    val durationMs: Long = 0,
    val channelNumber: String? = null,
    val channelName: String? = null,
    val channelLogoUrl: String? = null,
    val channelLogoPosition: String? = null,
    val channelLogoOverlayEnabled: Boolean? = null,
    val leafCount: Int = 0,
    val seasonCount: Int = 0,
    val episodeCount: Int = 0,
    val resumeTitle: String? = null,
    val recentItems: List<MediaItem> = emptyList(),
    val artworkResource: Int? = null,
) {
    val preferredArtwork: String?
        get() = episodeStill ?: seasonPoster ?: seriesPoster ?: poster ?: backdrop

    val wideArtwork: String?
        get() = backdrop ?: episodeStill ?: poster ?: seriesPoster ?: seasonPoster

    val isLiveChannel: Boolean
        get() = mediaType.equals("channel", true) || mediaType.equals("live", true) || type.equals("channel", true)

    val canPlay: Boolean
        get() = !streamUrl.isNullOrBlank()

    val isBrowsable: Boolean
        get() {
            if (canPlay || !nzbUrl.isNullOrBlank()) return false
            val kind = (mediaType ?: type).orEmpty().lowercase()
            return !categoryId.isNullOrBlank() && !path.isNullOrBlank() &&
                kind in setOf("show", "series", "season", "folder", "tvshow")
        }

    val isEpisode: Boolean
        get() = (mediaType ?: type).orEmpty().lowercase() in setOf("episode", "tv")
}

data class PlayerHome(
    val serverName: String = "Tater Tube Server",
    val serverVersion: String? = null,
    val capabilities: PlayerCapabilities = PlayerCapabilities(),
    val hero: HomeHero = HomeHero(),
    val continueWatching: List<MediaItem> = emptyList(),
    val recentlyAdded: List<MediaItem> = emptyList(),
    val liveChannels: List<MediaItem> = emptyList(),
)

data class PairResponse(val token: String, val playerName: String = "Tater Tube Player")

data class LibraryEntry(val id: String, val title: String, val type: String? = null)
data class LibraryRow(val title: String, val entry: LibraryEntry, val items: List<MediaItem>)
data class LibraryPage(val title: String, val items: List<MediaItem>)

data class LibraryLocation(
    val categoryId: String,
    val title: String,
    val sourceIndex: Int = -1,
    val path: String = "",
    val continueWatching: Boolean = false,
    val backdrop: String? = null,
    val poster: String? = null,
    val summary: String? = null,
    val mediaType: String? = null,
    val initialFocusItemId: String? = null,
) {
    val cacheKey: String
        get() = listOf(categoryId, sourceIndex.toString(), path, if (continueWatching) "continue" else "browse")
            .joinToString("|")

    companion object {
        val AllMovies = LibraryLocation("local-discover:movies", "All Movies", mediaType = "movie")
        val AllShows = LibraryLocation("local-discover:series", "All TV Shows", mediaType = "show")

        fun fromEntry(entry: LibraryEntry) = LibraryLocation(
            categoryId = entry.id,
            title = entry.title,
            continueWatching = entry.type.equals("continue", true),
        )

        fun fromItem(item: MediaItem, parent: LibraryLocation) = LibraryLocation(
            categoryId = item.categoryId ?: parent.categoryId,
            title = item.title,
            sourceIndex = item.sourceIndex,
            path = item.path.orEmpty(),
            backdrop = item.backdrop ?: parent.backdrop,
            poster = item.seriesPoster ?: item.seasonPoster ?: item.poster ?: parent.poster,
            summary = item.summary ?: parent.summary,
            mediaType = item.mediaType ?: item.type,
        )
    }
}

data class DiscoverCategory(
    val id: String,
    val title: String,
    val detail: String? = null,
    val type: String? = null,
    val fullTitle: String? = null,
    val category: String? = null,
    val time: String? = null,
    val children: List<DiscoverCategory> = emptyList(),
) {
    val artworkKey: String
        get() = when {
            id.equals("movie:top", true) -> "popular-movies"
            id.startsWith("movie:year:", true) -> "new-movies"
            id.equals("movie:imdbrating", true) -> "featured-movies"
            id.equals("series:top", true) -> "popular-tv"
            id.startsWith("series:year:", true) -> "new-tv"
            id.equals("series:imdbrating", true) -> "featured-tv"
            category.equals("series", true) -> "featured-tv"
            else -> "featured-movies"
        }
}

data class DiscoverPreparedFile(val id: String, val filename: String, val playbackItem: MediaItem)

data class RecommendationBatch(
    val id: String,
    val assistantName: String = "Tater",
    val summary: String = "",
    val picksBriefing: String? = null,
)

data class RecommendationItem(
    val id: String,
    val rank: Int,
    val title: String,
    val mediaType: String? = null,
    val reason: String,
    val launch: MediaItem,
)

data class Recommendations(val batch: RecommendationBatch?, val items: List<RecommendationItem>)
data class TtsRequest(val id: String, val status: String, val error: String? = null)

data class PlaybackAudioTrack(
    val index: Int,
    val streamIndex: Int? = null,
    val codec: String? = null,
    val channels: Int? = null,
    val language: String? = null,
    val title: String? = null,
    val isDefault: Boolean = false,
    val commentary: Boolean = false,
    val descriptive: Boolean = false,
)

data class PlaybackSource(
    val durationSeconds: Double? = null,
    val audioTracks: List<PlaybackAudioTrack> = emptyList(),
)

data class PlaybackPlan(
    val streamUrl: String,
    val mode: String = "direct",
    val videoMode: String = "direct",
    val audioMode: String = "direct",
    val videoCodec: String? = null,
    val audioCodec: String? = null,
    val qualityLabel: String = "Best available",
    val resolutionLabel: String? = null,
    val outputContainer: String? = null,
    val outputAudioChannels: Int? = null,
    val sourceVideoRange: String? = null,
    val outputVideoRange: String? = null,
    val outputFrameRate: Double? = null,
    val selectedAudioTrack: Int = 0,
    val source: PlaybackSource = PlaybackSource(),
)

data class LiveGuide(
    val channels: List<LiveChannel>,
    val startedAt: String? = null,
    val serverNow: String? = null,
    val receivedAtMs: Long = System.currentTimeMillis(),
) {
    fun elapsedSeconds(nowMs: Long = System.currentTimeMillis()): Double {
        val started = parseServerDate(startedAt) ?: return 0.0
        val serverReference = parseServerDate(serverNow) ?: receivedAtMs
        return ((serverReference - started) + (nowMs - receivedAtMs)).coerceAtLeast(0).toDouble() / 1000.0
    }

    fun startTime(program: LiveProgram): Date? = parseServerDate(startedAt)?.let {
        Date(it + (program.start * 1000.0).toLong())
    }
}

data class LiveChannel(
    val id: String,
    val number: String,
    val title: String,
    val logoUrl: String? = null,
    val logoTitle: String? = null,
    val logoPosition: String? = null,
    val logoOverlayEnabled: Boolean? = null,
    val autoGenerated: Boolean = false,
    val streamUrl: String? = null,
    val now: LiveProgram? = null,
    val next: LiveProgram? = null,
    val schedule: List<LiveProgram> = emptyList(),
) {
    fun playbackItem() = MediaItem(
        id = "tube-tv:$number",
        title = now?.title ?: title,
        type = "channel",
        subtitle = next?.let { "Up next: ${it.title}" }
            ?: if (number.isBlank()) "Live on Tater Tube" else "Channel $number",
        summary = now?.summary ?: "Now playing on $title",
        mediaType = "channel",
        category = now?.category,
        categoryId = now?.categoryId,
        sourceIndex = now?.sourceIndex ?: 0,
        path = now?.path,
        poster = now?.poster ?: logoUrl,
        backdrop = now?.backdrop,
        seriesPoster = now?.seriesPoster,
        seasonPoster = now?.seasonPoster,
        episodeStill = now?.episodeStill,
        streamUrl = streamUrl,
        channelNumber = number,
        channelName = title,
        channelLogoUrl = logoUrl,
        channelLogoPosition = logoPosition,
        channelLogoOverlayEnabled = logoOverlayEnabled,
        progressPercent = now?.progressPercent ?: 0.0,
    )

    fun displayedPrograms(elapsed: Double): List<LiveProgram> {
        if (schedule.isEmpty()) return listOfNotNull(now?.asBreakIfNeeded(), next?.takeUnless { it.isInterstitial })
        val programs = mutableListOf<LiveProgram>()
        var futureIndex = schedule.size
        val currentIndex = schedule.indexOfFirst { it.start <= elapsed && elapsed < it.end }
        if (currentIndex >= 0) {
            val current = schedule[currentIndex]
            programs += if (current.isInterstitial) LiveProgram.commercialBreak(schedule, currentIndex) else current
            futureIndex = currentIndex + 1
        } else {
            val nextIndex = schedule.indexOfFirst { it.start > elapsed }
            if (nextIndex >= 0) futureIndex = nextIndex
        }
        for (index in futureIndex until schedule.size) {
            val program = schedule[index]
            if (!program.isInterstitial) programs += program
            if (programs.size == 3) break
        }
        return programs
    }
}

data class LiveProgram(
    val id: String,
    val title: String,
    val kind: String? = null,
    val mediaType: String? = null,
    val category: String? = null,
    val categoryId: String? = null,
    val sourceIndex: Int = 0,
    val path: String? = null,
    val summary: String? = null,
    val start: Double = 0.0,
    val end: Double = 0.0,
    val duration: Double = 0.0,
    val progressPercent: Double = 0.0,
    val poster: String? = null,
    val backdrop: String? = null,
    val seriesPoster: String? = null,
    val seasonPoster: String? = null,
    val episodeStill: String? = null,
    val isCommercialBreak: Boolean = false,
) {
    val isInterstitial: Boolean
        get() = (kind ?: mediaType).orEmpty().lowercase() in
            setOf("commercial", "bumper", "tater_bumper", "commercial_break")

    val artwork: String?
        get() = backdrop ?: episodeStill ?: poster ?: seriesPoster ?: seasonPoster

    fun progress(elapsed: Double): Float = if (end > start) {
        ((elapsed - start) / (end - start)).coerceIn(0.0, 1.0).toFloat()
    } else (progressPercent / 100.0).coerceIn(0.0, 1.0).toFloat()

    fun asBreakIfNeeded(): LiveProgram = if (isInterstitial) copy(
        title = "Commercial Break",
        kind = "commercial_break",
        mediaType = "commercial_break",
        isCommercialBreak = true,
    ) else this

    companion object {
        fun commercialBreak(schedule: List<LiveProgram>, around: Int): LiveProgram {
            var first = around
            var last = around
            while (first > 0 && schedule[first - 1].isInterstitial) first--
            while (last + 1 < schedule.size && schedule[last + 1].isInterstitial) last++
            return LiveProgram(
                id = "break:${schedule[first].start}:${schedule[last].end}",
                title = "Commercial Break",
                kind = "commercial_break",
                mediaType = "commercial_break",
                start = schedule[first].start,
                end = schedule[last].end,
                duration = (schedule[last].end - schedule[first].start).coerceAtLeast(0.0),
                isCommercialBreak = true,
            )
        }
    }
}

object ModelParser {
    fun envelope(raw: String): JSONObject {
        val root = JSONObject(raw)
        if (root.has("success") && !root.optBoolean("success", true)) {
            throw IllegalStateException(root.string("message", "error") ?: "The server rejected the request.")
        }
        return root.optJSONObject("data") ?: root
    }

    fun pair(raw: String): PairResponse {
        val data = envelope(raw)
        return PairResponse(
            token = data.string("token") ?: error("The server did not return a player token."),
            playerName = data.string("playerName", "player_name") ?: "Tater Tube Player",
        )
    }

    fun home(raw: String): PlayerHome {
        val data = envelope(raw)
        val capability = data.optJSONObject("capabilities") ?: JSONObject()
        val hero = data.optJSONObject("hero") ?: JSONObject()
        return PlayerHome(
            serverName = data.string("serverName", "server_name") ?: "Tater Tube Server",
            serverVersion = data.string("serverVersion", "server_version"),
            capabilities = PlayerCapabilities(
                localMedia = capability.optBoolean("localMedia", false),
                newznab = capability.optBoolean("newznab", false),
                tubeTV = capability.optBoolean("tubeTV", false),
                commercials = capability.optBoolean("commercials", false),
                taterLink = capability.optBoolean("taterLink", false),
            ),
            hero = HomeHero(
                eyebrow = hero.string("eyebrow") ?: "Everything good, right where you left it",
                message = hero.string("message") ?: "Your Tater Tube is ready.",
                personalized = hero.optBoolean("personalized", false),
            ),
            continueWatching = data.array("continueWatching", "continue_watching").mediaItems(),
            recentlyAdded = data.array("recentlyAdded", "recently_added").mediaItems(),
            liveChannels = data.array("liveChannels", "live_channels").mediaItems("channel"),
        )
    }

    fun libraryRows(raw: String): List<LibraryRow> {
        val data = envelope(raw)
        val rows = data.optJSONArray("rows") ?: JSONArray()
        return buildList {
            repeat(rows.length()) { index ->
                val row = rows.optJSONObject(index) ?: return@repeat
                val entryObject = row.optJSONObject("entry") ?: JSONObject()
                val title = row.string("title") ?: entryObject.string("title") ?: "Library"
                val entry = LibraryEntry(
                    id = entryObject.string("id") ?: "library:$title",
                    title = entryObject.string("title") ?: title,
                    type = entryObject.string("type"),
                )
                add(LibraryRow(title, entry, row.optJSONArray("items").mediaItems()))
            }
        }
    }

    fun libraryPage(raw: String): LibraryPage {
        val data = envelope(raw)
        return LibraryPage(data.string("title") ?: "Library", data.optJSONArray("items").mediaItems())
    }

    fun nextEpisode(raw: String): MediaItem? = envelope(raw).optJSONObject("item")?.mediaItem()

    fun discoverCategories(raw: String): List<DiscoverCategory> {
        val categories = envelope(raw).optJSONArray("categories").discoverCategories()
        val stream = categories.firstOrNull { it.id.equals("stream", true) }
        return stream?.children?.firstOrNull { it.type.equals("discoverRoot", true) }?.children.orEmpty()
    }

    fun recommendations(raw: String): Recommendations {
        val data = envelope(raw)
        val batchObject = data.optJSONObject("batch")
        val batch = batchObject?.let {
            RecommendationBatch(
                id = it.string("id").orEmpty(),
                assistantName = it.string("assistantName") ?: "Tater",
                summary = it.string("summary").orEmpty(),
                picksBriefing = it.string("picksBriefing"),
            )
        }
        val array = data.optJSONArray("items") ?: JSONArray()
        val items = buildList {
            repeat(array.length()) { index ->
                val item = array.optJSONObject(index) ?: return@repeat
                val launch = item.optJSONObject("launch")?.mediaItem() ?: return@repeat
                add(RecommendationItem(
                    id = item.string("id", "candidateId") ?: "pick:$index:${launch.title}",
                    rank = item.optInt("rank", index + 1),
                    title = item.string("title") ?: launch.title,
                    mediaType = item.string("mediaType"),
                    reason = item.string("reason") ?: "Tater thinks this belongs on your screen.",
                    launch = launch,
                ))
            }
        }.sortedWith(compareBy<RecommendationItem> { it.rank }.thenBy { it.title })
        return Recommendations(batch, items)
    }

    fun ttsRequest(raw: String): TtsRequest {
        val data = envelope(raw)
        return TtsRequest(data.string("id").orEmpty(), data.string("status") ?: "pending", data.string("error"))
    }

    fun discoverPlayback(raw: String, release: MediaItem, source: MediaItem): List<DiscoverPreparedFile> {
        val data = envelope(raw)
        val streams = data.optJSONArray("streams") ?: JSONArray()
        val playStateId = data.string("_tater_play_state_id") ?: release.playStateId ?: source.playStateId
        val nzbUrl = data.string("_tater_nzb_url") ?: release.nzbUrl
        return buildList {
            repeat(streams.length()) { index ->
                val stream = streams.optJSONObject(index) ?: return@repeat
                val url = stream.string("url", "streamUrl") ?: return@repeat
                val filename = stream.string("title", "name") ?: "Playable file ${index + 1}"
                val title = source.discoverSourceTitle ?: source.title
                val item = source.copy(
                    id = playStateId ?: "${source.id}:stream:$index",
                    title = title,
                    type = "nzbStream",
                    subtitle = filename,
                    mediaType = source.mediaType ?: release.mediaType,
                    category = source.category ?: release.category,
                    categoryId = "discover",
                    playStateId = playStateId,
                    nzbUrl = nzbUrl,
                    discoverStreamIndex = index,
                    discoverSourceTitle = title,
                    poster = source.poster ?: release.poster,
                    backdrop = source.backdrop ?: release.backdrop,
                    streamUrl = url,
                )
                add(DiscoverPreparedFile("${item.id}:$index", filename, item))
            }
        }
    }

    fun playbackPlan(raw: String): PlaybackPlan {
        val data = envelope(raw)
        val source = data.optJSONObject("source") ?: JSONObject()
        val tracks = source.array("audioTracks", "audio_tracks") ?: JSONArray()
        return PlaybackPlan(
            streamUrl = data.string("streamUrl", "stream_url") ?: error("The server did not return a playable stream."),
            mode = data.string("mode") ?: "direct",
            videoMode = data.string("videoMode", "video_mode") ?: "direct",
            audioMode = data.string("audioMode", "audio_mode") ?: "direct",
            videoCodec = data.string("videoCodec", "video_codec"),
            audioCodec = data.string("audioCodec", "audio_codec"),
            qualityLabel = data.string("qualityLabel", "quality_label") ?: "Best available",
            resolutionLabel = data.string("resolutionLabel", "resolution_label"),
            outputContainer = data.string("outputContainer", "output_container"),
            outputAudioChannels = data.flexibleInt("outputAudioChannels", "output_audio_channels"),
            sourceVideoRange = data.string("sourceVideoRange", "source_video_range"),
            outputVideoRange = data.string("outputVideoRange", "output_video_range"),
            outputFrameRate = data.flexibleDouble("outputFrameRate", "output_frame_rate"),
            selectedAudioTrack = data.flexibleInt("selectedAudioTrack", "selected_audio_track") ?: 0,
            source = PlaybackSource(
                durationSeconds = source.flexibleDouble("durationSeconds", "duration_seconds"),
                audioTracks = buildList {
                    repeat(tracks.length()) { index ->
                        val track = tracks.optJSONObject(index) ?: return@repeat
                        add(PlaybackAudioTrack(
                            index = track.optInt("index", index),
                            streamIndex = track.flexibleInt("streamIndex", "stream_index"),
                            codec = track.string("codec"),
                            channels = track.flexibleInt("channels"),
                            language = track.string("language"),
                            title = track.string("title"),
                            isDefault = track.optBoolean("default", false),
                            commentary = track.optBoolean("commentary", false),
                            descriptive = track.optBoolean("descriptive", false),
                        ))
                    }
                },
            ),
        )
    }

    fun liveGuide(raw: String): LiveGuide {
        val data = envelope(raw)
        val channels = data.optJSONArray("channels") ?: JSONArray()
        return LiveGuide(
            channels = buildList { repeat(channels.length()) { index -> channels.optJSONObject(index)?.let { add(it.liveChannel()) } } },
            startedAt = data.string("startedAt"),
            serverNow = data.string("serverNow"),
        )
    }

    private fun JSONObject.liveChannel(): LiveChannel {
        val number = string("number").orEmpty()
        val title = string("title") ?: "Tater Tube"
        return LiveChannel(
            id = string("id") ?: "$number:$title",
            number = number,
            title = title,
            logoUrl = string("logoUrl", "logoURL", "logoPath"),
            logoTitle = string("logoTitle"),
            logoPosition = string("logoPosition"),
            logoOverlayEnabled = nullableBoolean("logoOverlayEnabled"),
            autoGenerated = optBoolean("autoGenerated", false),
            streamUrl = string("streamUrl"),
            now = optJSONObject("now")?.liveProgram(),
            next = optJSONObject("next")?.liveProgram(),
            schedule = optJSONArray("schedule").livePrograms(),
        )
    }

    private fun JSONObject.liveProgram(): LiveProgram {
        val title = string("title") ?: "Tater Tube"
        val start = flexibleDouble("start") ?: 0.0
        val end = flexibleDouble("end") ?: 0.0
        return LiveProgram(
            id = string("id") ?: "${string("kind")}:$title:$start:$end",
            title = title,
            kind = string("kind"),
            mediaType = string("mediaType"),
            category = string("category"),
            categoryId = string("categoryId"),
            sourceIndex = optInt("sourceIndex", 0),
            path = string("path"),
            summary = string("summary", "description"),
            start = start,
            end = end,
            duration = flexibleDouble("duration") ?: (end - start).coerceAtLeast(0.0),
            progressPercent = flexibleDouble("progressPercent") ?: 0.0,
            poster = string("poster"),
            backdrop = string("backdrop"),
            seriesPoster = string("seriesPoster"),
            seasonPoster = string("seasonPoster"),
            episodeStill = string("episodeStill"),
            isCommercialBreak = optBoolean("isCommercialBreak", false),
        )
    }

    private fun JSONObject.mediaItem(defaultType: String? = null): MediaItem {
        val title = string("title", "channelName") ?: "Untitled"
        val durationMs = if (has("durationSeconds")) {
            ((flexibleDouble("durationSeconds") ?: 0.0) * 1000).toLong()
        } else ((flexibleDouble("duration") ?: 0.0) * 1000).toLong()
        val viewOffsetMs = if (has("viewOffsetSeconds")) {
            ((flexibleDouble("viewOffsetSeconds") ?: 0.0) * 1000).toLong()
        } else flexibleLong("viewOffset") ?: 0
        val identifier = listOf("id", "playStateId", "ratingKey", "partKey", "key", "path", "streamUrl", "nzbUrl")
            .firstNotNullOfOrNull { string(it) } ?: "${defaultType ?: "media"}:$title"
        return MediaItem(
            id = identifier,
            title = title,
            type = string("type"),
            subtitle = string("subtitle"),
            summary = string("summary", "overview", "description"),
            tagline = string("tagline"),
            contentRating = string("contentRating"),
            communityRating = flexibleDouble("communityRating"),
            mediaType = string("mediaType", "type") ?: defaultType,
            category = string("category"),
            categoryId = string("categoryId"),
            sourceIndex = optInt("sourceIndex", 0),
            path = string("path"),
            playStateId = string("playStateId"),
            seriesStateId = string("seriesStateId"),
            seriesTitle = string("seriesTitle"),
            nzbUrl = string("nzbUrl"),
            discoverStreamIndex = optInt("discoverStreamIndex", 0),
            discoverSourceTitle = string("discoverSourceTitle"),
            searchQuery = string("searchQuery"),
            guid = string("guid"),
            sizeText = string("sizeText"),
            files = string("files"),
            grabs = string("grabs"),
            date = string("date"),
            poster = string("poster"),
            backdrop = string("backdrop"),
            seriesPoster = string("seriesPoster"),
            seasonPoster = string("seasonPoster"),
            episodeStill = string("episodeStill"),
            streamUrl = string("streamUrl", "stream_url"),
            progressPercent = (flexibleDouble("progressPercent") ?: 0.0).coerceIn(0.0, 100.0),
            viewOffsetMs = viewOffsetMs.coerceAtLeast(0),
            durationMs = durationMs.coerceAtLeast(0),
            channelNumber = string("channelNumber"),
            channelName = string("channelName"),
            channelLogoUrl = string("channelLogoUrl", "logoUrl"),
            channelLogoPosition = string("channelLogoPosition", "logoPosition"),
            channelLogoOverlayEnabled = nullableBoolean("channelLogoOverlayEnabled", "logoOverlayEnabled"),
            leafCount = optInt("leafCount", 0),
            seasonCount = optInt("seasonCount", 0),
            episodeCount = optInt("episodeCount", 0),
            resumeTitle = string("resumeTitle"),
            recentItems = optJSONArray("recentItems").mediaItems(),
        )
    }

    private fun JSONArray?.mediaItems(defaultType: String? = null): List<MediaItem> {
        if (this == null) return emptyList()
        return buildList { repeat(length()) { index -> optJSONObject(index)?.let { add(it.mediaItem(defaultType)) } } }
    }

    private fun JSONArray?.discoverCategories(): List<DiscoverCategory> {
        if (this == null) return emptyList()
        return buildList {
            repeat(length()) { index ->
                val item = optJSONObject(index) ?: return@repeat
                val title = item.string("title") ?: "Discover"
                add(DiscoverCategory(
                    id = item.string("id") ?: "discover:$title",
                    title = title,
                    detail = item.string("detail"),
                    type = item.string("type"),
                    fullTitle = item.string("fullTitle"),
                    category = item.string("category"),
                    time = item.string("time"),
                    children = item.optJSONArray("children").discoverCategories(),
                ))
            }
        }
    }

    private fun JSONArray?.livePrograms(): List<LiveProgram> {
        if (this == null) return emptyList()
        return buildList { repeat(length()) { index -> optJSONObject(index)?.let { add(it.liveProgram()) } } }
    }
}

private fun JSONObject.string(vararg keys: String): String? {
    for (key in keys) {
        if (!has(key) || isNull(key)) continue
        val value = opt(key)?.toString()?.trim().orEmpty()
        if (value.isNotEmpty() && !value.equals("null", true)) return value
    }
    return null
}

private fun JSONObject.array(vararg keys: String): JSONArray? = keys.firstNotNullOfOrNull { optJSONArray(it) }

private fun JSONObject.flexibleLong(vararg keys: String): Long? {
    for (key in keys) {
        val value = opt(key)
        if (value is Number) return value.toLong()
        if (value is String) value.toDoubleOrNull()?.toLong()?.let { return it }
    }
    return null
}

private fun JSONObject.flexibleDouble(vararg keys: String): Double? {
    for (key in keys) {
        val value = opt(key)
        if (value is Number) return value.toDouble()
        if (value is String) value.toDoubleOrNull()?.let { return it }
    }
    return null
}

private fun JSONObject.flexibleInt(vararg keys: String): Int? = flexibleLong(*keys)?.toInt()

private fun JSONObject.nullableBoolean(vararg keys: String): Boolean? {
    for (key in keys) {
        if (!has(key) || isNull(key)) continue
        val value = opt(key)
        return if (value is Boolean) value
        else if (value is Number) value.toInt() != 0
        else if (value is String) value.equals("true", true) || value == "1"
        else null
    }
    return null
}

private fun parseServerDate(value: String?): Long? {
    if (value.isNullOrBlank()) return null
    val patterns = listOf(
        "yyyy-MM-dd'T'HH:mm:ss.SSSXXX",
        "yyyy-MM-dd'T'HH:mm:ssXXX",
        "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
        "yyyy-MM-dd'T'HH:mm:ss'Z'",
    )
    for (pattern in patterns) {
        val formatter = SimpleDateFormat(pattern, Locale.US).apply { timeZone = TimeZone.getTimeZone("UTC") }
        runCatching { formatter.parse(value)?.time }.getOrNull()?.let { return it }
    }
    return null
}
