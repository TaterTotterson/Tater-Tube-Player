package com.tatertotterson.tatertubeplayer.model

import org.json.JSONArray
import org.json.JSONObject

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
    val subtitle: String? = null,
    val summary: String? = null,
    val mediaType: String? = null,
    val category: String? = null,
    val categoryId: String? = null,
    val sourceIndex: Int = 0,
    val path: String? = null,
    val playStateId: String? = null,
    val seriesStateId: String? = null,
    val seriesTitle: String? = null,
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
    val artworkResource: Int? = null,
) {
    val preferredArtwork: String?
        get() = episodeStill ?: seasonPoster ?: seriesPoster ?: poster ?: backdrop

    val isLiveChannel: Boolean
        get() = mediaType.equals("channel", true) || mediaType.equals("live", true)

    val canPlay: Boolean
        get() = !streamUrl.isNullOrBlank()
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

data class PairResponse(
    val token: String,
    val playerName: String = "Tater Tube Player",
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
    val selectedAudioTrack: Int = 0,
)

object ModelParser {
    fun envelope(raw: String): JSONObject {
        val root = JSONObject(raw)
        if (root.has("success") && !root.optBoolean("success", true)) {
            throw IllegalStateException(
                root.nullableString("message") ?: root.nullableString("error") ?: "The server rejected the request."
            )
        }
        return root.optJSONObject("data") ?: root
    }

    fun pair(raw: String): PairResponse {
        val data = envelope(raw)
        val token = data.nullableString("token")
            ?: throw IllegalStateException("The server did not return a player token.")
        return PairResponse(
            token = token,
            playerName = data.nullableString("playerName") ?: "Tater Tube Player",
        )
    }

    fun home(raw: String): PlayerHome {
        val data = envelope(raw)
        val capability = data.optJSONObject("capabilities") ?: JSONObject()
        val hero = data.optJSONObject("hero") ?: JSONObject()
        return PlayerHome(
            serverName = data.nullableString("serverName") ?: "Tater Tube Server",
            serverVersion = data.nullableString("serverVersion"),
            capabilities = PlayerCapabilities(
                localMedia = capability.optBoolean("localMedia", false),
                newznab = capability.optBoolean("newznab", false),
                tubeTV = capability.optBoolean("tubeTV", false),
                commercials = capability.optBoolean("commercials", false),
                taterLink = capability.optBoolean("taterLink", false),
            ),
            hero = HomeHero(
                eyebrow = hero.nullableString("eyebrow") ?: "Everything good, right where you left it",
                message = hero.nullableString("message") ?: "Your Tater Tube is ready.",
                personalized = hero.optBoolean("personalized", false),
            ),
            continueWatching = data.optJSONArray("continueWatching").mediaItems(),
            recentlyAdded = data.optJSONArray("recentlyAdded").mediaItems(),
            liveChannels = data.optJSONArray("liveChannels").mediaItems(defaultType = "channel"),
        )
    }

    fun playbackPlan(raw: String): PlaybackPlan {
        val data = envelope(raw)
        val stream = data.nullableString("streamUrl")
            ?: data.nullableString("stream_url")
            ?: throw IllegalStateException("The server did not return a playable stream.")
        return PlaybackPlan(
            streamUrl = stream,
            mode = data.nullableString("mode") ?: "direct",
            videoMode = data.nullableString("videoMode") ?: "direct",
            audioMode = data.nullableString("audioMode") ?: "direct",
            videoCodec = data.nullableString("videoCodec"),
            audioCodec = data.nullableString("audioCodec"),
            qualityLabel = data.nullableString("qualityLabel") ?: "Best available",
            resolutionLabel = data.nullableString("resolutionLabel"),
            outputContainer = data.nullableString("outputContainer"),
            selectedAudioTrack = data.optInt("selectedAudioTrack", 0),
        )
    }

    private fun JSONArray?.mediaItems(defaultType: String? = null): List<MediaItem> {
        if (this == null) return emptyList()
        return buildList {
            repeat(length()) { index ->
                optJSONObject(index)?.let { add(it.mediaItem(defaultType)) }
            }
        }
    }

    private fun JSONObject.mediaItem(defaultType: String?): MediaItem {
        val title = nullableString("title") ?: nullableString("channelName") ?: "Untitled"
        val durationMs = when {
            has("durationSeconds") -> (optDouble("durationSeconds", 0.0) * 1000).toLong()
            else -> flexibleLong("duration")
        }
        val viewOffsetMs = when {
            has("viewOffsetSeconds") -> (optDouble("viewOffsetSeconds", 0.0) * 1000).toLong()
            else -> flexibleLong("viewOffset")
        }
        val identifier = listOf(
            nullableString("id"),
            nullableString("playStateId"),
            nullableString("ratingKey"),
            nullableString("key"),
            nullableString("path"),
            nullableString("streamUrl"),
        ).firstOrNull { !it.isNullOrBlank() } ?: "${defaultType ?: "media"}:$title"

        return MediaItem(
            id = identifier,
            title = title,
            subtitle = nullableString("subtitle"),
            summary = nullableString("summary") ?: nullableString("overview") ?: nullableString("description"),
            mediaType = nullableString("mediaType") ?: nullableString("type") ?: defaultType,
            category = nullableString("category"),
            categoryId = nullableString("categoryId"),
            sourceIndex = optInt("sourceIndex", 0),
            path = nullableString("path"),
            playStateId = nullableString("playStateId"),
            seriesStateId = nullableString("seriesStateId"),
            seriesTitle = nullableString("seriesTitle"),
            poster = nullableString("poster"),
            backdrop = nullableString("backdrop"),
            seriesPoster = nullableString("seriesPoster"),
            seasonPoster = nullableString("seasonPoster"),
            episodeStill = nullableString("episodeStill"),
            streamUrl = nullableString("streamUrl") ?: nullableString("stream_url"),
            progressPercent = optDouble("progressPercent", 0.0).coerceIn(0.0, 100.0),
            viewOffsetMs = viewOffsetMs.coerceAtLeast(0),
            durationMs = durationMs.coerceAtLeast(0),
            channelNumber = nullableString("channelNumber"),
            channelName = nullableString("channelName"),
            channelLogoUrl = nullableString("channelLogoUrl"),
        )
    }
}

private fun JSONObject.nullableString(key: String): String? {
    if (!has(key) || isNull(key)) return null
    return optString(key).trim().takeUnless { it.isEmpty() || it.equals("null", true) }
}

private fun JSONObject.flexibleLong(key: String): Long {
    if (!has(key) || isNull(key)) return 0
    val value = opt(key)
    if (value is Number) return value.toLong()
    if (value is String) return value.toDoubleOrNull()?.toLong() ?: 0
    return 0
}
