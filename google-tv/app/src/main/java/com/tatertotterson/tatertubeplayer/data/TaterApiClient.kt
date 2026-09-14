package com.tatertotterson.tatertubeplayer.data

import com.tatertotterson.tatertubeplayer.model.MediaItem
import com.tatertotterson.tatertubeplayer.model.DiscoverCategory
import com.tatertotterson.tatertubeplayer.model.DiscoverPreparedFile
import com.tatertotterson.tatertubeplayer.model.LibraryLocation
import com.tatertotterson.tatertubeplayer.model.LibraryPage
import com.tatertotterson.tatertubeplayer.model.LibraryRow
import com.tatertotterson.tatertubeplayer.model.LiveGuide
import com.tatertotterson.tatertubeplayer.model.LiveProgram
import com.tatertotterson.tatertubeplayer.model.ModelParser
import com.tatertotterson.tatertubeplayer.model.PairResponse
import com.tatertotterson.tatertubeplayer.model.PlaybackPlan
import com.tatertotterson.tatertubeplayer.model.PlayerHome
import com.tatertotterson.tatertubeplayer.model.Recommendations
import com.tatertotterson.tatertubeplayer.model.TtsRequest
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL
import java.net.URLEncoder
import java.util.Calendar

class TaterApiClient(
    val serverUrl: String,
    val token: String? = null,
) {
    suspend fun pair(pin: String): PairResponse {
        val body = JSONObject()
            .put("pin", pin)
            .put("name", "Tater Tube Player")
        return ModelParser.pair(request("/api/tater/players/pair", "POST", body, authenticated = false))
    }

    suspend fun home(): Pair<String, PlayerHome> {
        val raw = request("/api/v1/player/home?include_live=0")
        return raw to ModelParser.home(raw)
    }

    suspend fun libraryRows(shuffleSeed: String): Pair<String, List<LibraryRow>> {
        val raw = request(pathWithQuery("/api/v1/player/library", "shuffle_seed" to shuffleSeed))
        return raw to ModelParser.libraryRows(raw)
    }

    suspend fun libraryPage(location: LibraryLocation, shuffleSeed: String): Pair<String, LibraryPage> {
        val path = if (location.continueWatching) {
            "/api/tater/playstate/continue"
        } else {
            val fields = mutableListOf(
                "category_id" to location.categoryId,
                "title" to location.title,
            )
            if (location.sourceIndex >= 0) fields += "source" to location.sourceIndex.toString()
            if (location.path.isNotBlank()) fields += "path" to location.path
            if (location.categoryId.startsWith("local-discover:")) {
                fields += "full" to "1"
                fields += "shuffle_seed" to shuffleSeed
            }
            pathWithQuery("/api/tater/usenet/items", *fields.toTypedArray())
        }
        val raw = request(path)
        return raw to ModelParser.libraryPage(raw)
    }

    suspend fun liveGuide(): Pair<String, LiveGuide> {
        val raw = request("/api/tater/tv/lineup?window=player")
        return raw to ModelParser.liveGuide(raw)
    }

    suspend fun discoverCatalog(): Pair<String, List<DiscoverCategory>> {
        val raw = request("/api/tater/usenet/catalog")
        return raw to ModelParser.discoverCategories(raw)
    }

    suspend fun discoverFeed(category: DiscoverCategory): Pair<String, LibraryPage> {
        val raw = request(pathWithQuery("/api/tater/usenet/discover", "catalog" to category.id))
        return raw to ModelParser.libraryPage(raw)
    }

    suspend fun discoverSearch(item: MediaItem): Pair<String, LibraryPage> {
        val query = (item.searchQuery ?: item.title).trim()
        require(query.length >= 3) { "This title could not be searched." }
        val raw = request(pathWithQuery("/api/tater/usenet/search", "q" to query))
        return raw to ModelParser.libraryPage(raw)
    }

    suspend fun prepareDiscovery(release: MediaItem, source: MediaItem): List<DiscoverPreparedFile> {
        val nzbUrl = release.nzbUrl?.takeIf { it.isNotBlank() }
            ?: throw IllegalStateException("This result does not include an NZB link.")
        val body = JSONObject()
            .put("nzb_url", nzbUrl)
            .put("title", source.discoverSourceTitle ?: source.title)
            .put("category", release.category ?: source.category ?: "tater-tube")
            .put("timeout", 300)
        val raw = request("/api/tater/usenet/play", "POST", body, timeoutMs = 315_000)
        return ModelParser.discoverPlayback(raw, release, source).map { prepared ->
            prepared.copy(playbackItem = prepared.playbackItem.copy(streamUrl = resolveUrl(prepared.playbackItem.streamUrl.orEmpty())))
        }
    }

    suspend fun recommendations(): Pair<String, Recommendations> {
        val raw = request("/api/tater/recommendations")
        return raw to ModelParser.recommendations(raw)
    }

    suspend fun createRecommendationSpeech(batchId: String): TtsRequest {
        val body = JSONObject()
            .put("profile_id", "household")
            .put("batch_id", batchId)
            .put("briefing_kind", "recommendations")
            .put("local_hour", Calendar.getInstance().get(Calendar.HOUR_OF_DAY))
        return ModelParser.ttsRequest(request("/api/tater/tts/requests", "POST", body))
    }

    suspend fun recommendationSpeechStatus(requestId: String): TtsRequest =
        ModelParser.ttsRequest(request("/api/tater/tts/requests/$requestId"))

    suspend fun recommendationSpeechAudio(requestId: String): ByteArray =
        requestBytes("/api/tater/tts/requests/$requestId/audio", accept = "audio/wav", timeoutMs = 20_000)

    suspend fun cancelRecommendationSpeech(requestId: String) {
        runCatching { request("/api/tater/tts/requests/$requestId", "DELETE") }
    }

    suspend fun reportCapabilities(capabilities: PlaybackCapabilities) {
        request(
            path = "/api/v1/player/capabilities",
            method = "POST",
            body = capabilities.toJson(),
            timeoutMs = 12_000,
        )
    }

    suspend fun playbackPlan(
        item: MediaItem,
        capabilities: PlaybackCapabilities,
        audioTrack: Int? = null,
    ): PlaybackPlan {
        var source = item.streamUrl?.takeIf { it.isNotBlank() }
            ?: throw IllegalStateException("This item does not include a playable stream.")
        if (item.isLiveChannel && item.channelLogoOverlayEnabled == true && !item.channelLogoUrl.isNullOrBlank()) {
            source += if (source.contains('?')) "&tater_client_logo_overlay=1" else "?tater_client_logo_overlay=1"
        }
        val body = JSONObject()
            .put("stream_url", source)
            .put("media_type", item.mediaType ?: "video")
            .put("profile", capabilities.profile)
            .put("force_probe", false)
        if (audioTrack != null) body.put("audio_track", audioTrack)
        val raw = request(
            path = "/api/v1/player/playback/sessions",
            method = "POST",
            body = body,
            timeoutMs = 45_000,
        )
        return ModelParser.playbackPlan(raw).let { it.copy(streamUrl = resolveUrl(it.streamUrl)) }
    }

    suspend fun clearPlayState(item: MediaItem) {
        val body = playStateBody(item, 0, 0, completed = true, playbackActive = false)
        request("/api/tater/playstate", "DELETE", body)
    }

    suspend fun nextEpisode(item: MediaItem): MediaItem? {
        if (!item.isEpisode || item.path.isNullOrBlank()) return null
        val body = JSONObject()
            .put("id", item.playStateId ?: item.id)
            .put("seriesId", item.seriesStateId ?: JSONObject.NULL)
            .put("title", item.title)
            .put("seriesTitle", item.seriesTitle ?: JSONObject.NULL)
            .put("mediaType", "episode")
            .put("categoryId", item.categoryId ?: JSONObject.NULL)
            .put("sourceIndex", item.sourceIndex)
            .put("path", item.path)
        return ModelParser.nextEpisode(request("/api/tater/playstate/next", "POST", body))
    }

    suspend fun savePlayState(
        item: MediaItem,
        positionMs: Long,
        durationMs: Long,
        completed: Boolean,
        playbackActive: Boolean,
    ) {
        val body = playStateBody(item, positionMs, durationMs, completed, playbackActive)
        request("/api/tater/playstate", "POST", body)
    }

    private fun playStateBody(
        item: MediaItem,
        positionMs: Long,
        durationMs: Long,
        completed: Boolean,
        playbackActive: Boolean,
    ): JSONObject = JSONObject()
            .put("id", item.playStateId ?: item.id)
            .put("seriesId", item.seriesStateId ?: JSONObject.NULL)
            .put("title", item.title)
            .put("seriesTitle", item.seriesTitle ?: JSONObject.NULL)
            .put("mediaType", item.mediaType ?: JSONObject.NULL)
            .put("category", item.category ?: JSONObject.NULL)
            .put("categoryId", item.categoryId ?: JSONObject.NULL)
            .put("sourceIndex", item.sourceIndex)
            .put("path", item.path ?: JSONObject.NULL)
            .put("positionMs", positionMs.coerceAtLeast(0))
            .put("durationMs", durationMs.coerceAtLeast(0))
            .put("completed", completed)
            .put("playbackActive", playbackActive && !completed)

    fun resolveUrl(value: String): String {
        val trimmed = value.trim()
        if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) return trimmed
        return if (trimmed.startsWith('/')) "$serverUrl$trimmed" else "$serverUrl/$trimmed"
    }

    fun guideArtworkUrl(program: LiveProgram): String? {
        program.artwork?.takeIf { it.isNotBlank() }?.let { return resolveUrl(it) }
        val categoryId = program.categoryId?.takeIf { it.isNotBlank() } ?: return null
        val mediaPath = program.path?.takeIf { it.isNotBlank() } ?: return null
        return resolveUrl(pathWithQuery(
            "/api/v1/player/artwork/local",
            "category_id" to categoryId,
            "source" to program.sourceIndex.toString(),
            "path" to mediaPath,
            "thumbnail" to "poster",
        ))
    }

    private fun pathWithQuery(path: String, vararg values: Pair<String, String>): String =
        path + values.joinToString(prefix = "?", separator = "&") { (key, value) ->
            "${URLEncoder.encode(key, Charsets.UTF_8.name())}=${URLEncoder.encode(value, Charsets.UTF_8.name())}"
        }

    private suspend fun requestBytes(
        path: String,
        accept: String,
        timeoutMs: Int,
    ): ByteArray = withContext(Dispatchers.IO) {
        val connection = URL(resolveUrl(path)).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "GET"
            connection.connectTimeout = 8_000
            connection.readTimeout = timeoutMs
            connection.instanceFollowRedirects = false
            connection.setRequestProperty("Accept", accept)
            if (!token.isNullOrBlank()) connection.setRequestProperty("Authorization", "Bearer $token")
            val status = connection.responseCode
            if (status !in 200..299) throw IllegalStateException("Tater Tube Server returned HTTP $status.")
            connection.inputStream.use { it.readBytes() }.also {
                require(it.size <= 8 * 1024 * 1024) { "Tater's voice returned an unexpectedly large audio file." }
            }
        } finally {
            connection.disconnect()
        }
    }

    private suspend fun request(
        path: String,
        method: String = "GET",
        body: JSONObject? = null,
        authenticated: Boolean = true,
        timeoutMs: Int = 20_000,
    ): String = withContext(Dispatchers.IO) {
        val connection = URL(resolveUrl(path)).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = method
            connection.connectTimeout = 8_000
            connection.readTimeout = timeoutMs
            connection.instanceFollowRedirects = false
            connection.setRequestProperty("Accept", "application/json")
            if (authenticated && !token.isNullOrBlank()) {
                connection.setRequestProperty("Authorization", "Bearer $token")
            }
            if (body != null) {
                connection.doOutput = true
                connection.setRequestProperty("Content-Type", "application/json")
                connection.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
            }

            val status = connection.responseCode
            if (status in 300..399) throw IllegalStateException("The server returned an unsafe redirect.")
            val raw = (if (status in 200..299) connection.inputStream else connection.errorStream)
                ?.bufferedReader(Charsets.UTF_8)
                ?.use { it.readText() }
                .orEmpty()
            if (status !in 200..299) {
                val message = runCatching {
                    val error = JSONObject(raw)
                    error.optString("message").ifBlank { error.optString("error") }
                }.getOrNull().orEmpty().ifBlank { "Tater Tube Server returned HTTP $status." }
                throw IllegalStateException(message)
            }
            raw
        } finally {
            connection.disconnect()
        }
    }

    companion object {
        fun normalizeServerUrl(input: String): String {
            val value = input.trim().let { if (it.contains("://")) it else "http://$it" }
            val uri = runCatching { URI(value) }.getOrNull()
                ?: throw IllegalArgumentException("Enter the address of your Tater Tube Server.")
            val scheme = uri.scheme?.lowercase()
            val host = uri.host?.lowercase()
                ?: throw IllegalArgumentException("Enter the address of your Tater Tube Server.")
            if (scheme != "http" && scheme != "https") {
                throw IllegalArgumentException("Use an HTTP or HTTPS server address.")
            }
            if (scheme == "http" && !isLocalHost(host)) {
                throw IllegalArgumentException("Use HTTPS for a server outside your local network.")
            }
            val port = if (uri.port >= 0) ":${uri.port}" else ""
            val path = uri.path?.trimEnd('/').orEmpty()
            return "$scheme://$host$port$path"
        }

        private fun isLocalHost(host: String): Boolean {
            if (host == "localhost" || host.endsWith(".local") || (!host.contains('.') && !host.contains(':'))) {
                return true
            }
            val bytes = host.split('.').mapNotNull { it.toIntOrNull() }
            if (bytes.size == 4 && bytes.all { it in 0..255 }) {
                return bytes[0] == 10 || bytes[0] == 127 ||
                    (bytes[0] == 169 && bytes[1] == 254) ||
                    (bytes[0] == 172 && bytes[1] in 16..31) ||
                    (bytes[0] == 192 && bytes[1] == 168)
            }
            return host == "::1" || host.startsWith("fc") || host.startsWith("fd") || host.startsWith("fe8") || host.startsWith("fe9") || host.startsWith("fea") || host.startsWith("feb")
        }
    }
}

data class PlaybackCapabilities(
    val videoCodecs: List<String>,
    val audioCodecs: List<String>,
    val audioPassthrough: List<String>,
    val videoHdrFormats: List<String>,
    val displayHdrFormats: List<String>,
    val displayHdrEnabled: Boolean,
    val maxVideoBitDepth: Int,
    val dolbyVisionProfiles: List<Int>,
    val maxWidth: Int,
    val maxHeight: Int,
    val maxAudioChannels: Int,
    val outputName: String,
    val outputConnection: String,
    val tubeTvOutputVideoRange: String?,
    val tubeTvOutputFrameRate: Double?,
) {
    val profile: String
        get() = when {
            maxWidth >= 3840 && maxHeight >= 2160 -> "hdmi_4k"
            maxWidth >= 1920 && maxHeight >= 1080 -> "hdmi_1080p"
            else -> "hdmi_720p"
        }

    fun toJson(): JSONObject = JSONObject()
        .put("capability_version", 6)
        .put("platform", "android_tv")
        .put("engine", "media3")
        .put("output_name", outputName)
        .put("output_connection", outputConnection)
        .put("containers", JSONArray(listOf("mp4", "matroska", "webm", "mpegts", "hls")))
        .put("video_codecs", JSONArray(videoCodecs))
        .put("audio_codecs", JSONArray(audioCodecs))
        .put("audio_passthrough", JSONArray(audioPassthrough))
        .put("passthrough_available", audioPassthrough.isNotEmpty())
        .put("audio_downmix", true)
        .put("video_hdr_formats", JSONArray(videoHdrFormats))
        .put("display_hdr_formats", JSONArray(displayHdrFormats))
        .put("display_hdr_enabled", displayHdrEnabled)
        .put("max_video_bit_depth", maxVideoBitDepth)
        .put("dolby_vision_profiles", JSONArray(dolbyVisionProfiles))
        .put("max_width", maxWidth)
        .put("max_height", maxHeight)
        .put("max_audio_channels", maxAudioChannels)
        .put("compatibility_mode", true)
        .put("preferred_stream_container", "hls")
        .put("tube_tv_output_video_range", tubeTvOutputVideoRange ?: JSONObject.NULL)
        .put("tube_tv_output_frame_rate", tubeTvOutputFrameRate ?: JSONObject.NULL)
}
