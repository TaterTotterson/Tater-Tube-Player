package com.tatertotterson.tatertubeplayer.data

import com.tatertotterson.tatertubeplayer.model.MediaItem
import com.tatertotterson.tatertubeplayer.model.ModelParser
import com.tatertotterson.tatertubeplayer.model.PairResponse
import com.tatertotterson.tatertubeplayer.model.PlaybackPlan
import com.tatertotterson.tatertubeplayer.model.PlayerHome
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL

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

    suspend fun reportCapabilities(capabilities: PlaybackCapabilities) {
        request(
            path = "/api/v1/player/capabilities",
            method = "POST",
            body = capabilities.toJson(),
            timeoutMs = 12_000,
        )
    }

    suspend fun playbackPlan(item: MediaItem, capabilities: PlaybackCapabilities): PlaybackPlan {
        val source = item.streamUrl?.takeIf { it.isNotBlank() }
            ?: throw IllegalStateException("This item does not include a playable stream.")
        val body = JSONObject()
            .put("stream_url", source)
            .put("media_type", item.mediaType ?: "video")
            .put("profile", capabilities.profile)
            .put("force_probe", false)
        val raw = request(
            path = "/api/v1/player/playback/sessions",
            method = "POST",
            body = body,
            timeoutMs = 45_000,
        )
        return ModelParser.playbackPlan(raw).let { it.copy(streamUrl = resolveUrl(it.streamUrl)) }
    }

    suspend fun savePlayState(
        item: MediaItem,
        positionMs: Long,
        durationMs: Long,
        completed: Boolean,
        playbackActive: Boolean,
    ) {
        val body = JSONObject()
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
        request("/api/tater/playstate", "POST", body)
    }

    fun resolveUrl(value: String): String {
        val trimmed = value.trim()
        if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) return trimmed
        return if (trimmed.startsWith('/')) "$serverUrl$trimmed" else "$serverUrl/$trimmed"
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
