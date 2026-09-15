package com.tatertotterson.tatertubeplayer.data

import com.tatertotterson.tatertubeplayer.R
import com.tatertotterson.tatertubeplayer.model.DiscoverCategory
import com.tatertotterson.tatertubeplayer.model.HomeHero
import com.tatertotterson.tatertubeplayer.model.LibraryEntry
import com.tatertotterson.tatertubeplayer.model.LibraryLocation
import com.tatertotterson.tatertubeplayer.model.LibraryPage
import com.tatertotterson.tatertubeplayer.model.LibraryRow
import com.tatertotterson.tatertubeplayer.model.LiveChannel
import com.tatertotterson.tatertubeplayer.model.LiveGuide
import com.tatertotterson.tatertubeplayer.model.LiveProgram
import com.tatertotterson.tatertubeplayer.model.MediaItem
import com.tatertotterson.tatertubeplayer.model.PlaybackPlan
import com.tatertotterson.tatertubeplayer.model.PlaybackSource
import com.tatertotterson.tatertubeplayer.model.PlayerCapabilities
import com.tatertotterson.tatertubeplayer.model.PlayerHome
import com.tatertotterson.tatertubeplayer.model.RecommendationBatch
import com.tatertotterson.tatertubeplayer.model.RecommendationItem
import com.tatertotterson.tatertubeplayer.model.Recommendations

object DemoCatalog {
    const val playbackDurationMs = 24_000L

    fun playbackPlan(resourceUri: String) = PlaybackPlan(
        streamUrl = resourceUri,
        mode = "direct",
        videoMode = "direct",
        audioMode = "direct",
        videoCodec = "h264",
        audioCodec = "aac",
        qualityLabel = "Rights-safe demo",
        resolutionLabel = "1080p",
        outputContainer = "mp4",
        outputAudioChannels = 2,
        source = PlaybackSource(durationSeconds = playbackDurationMs / 1000.0),
    )

    private val cosmicDrift = MediaItem(
        id = "demo-cosmic-drift",
        title = "Cosmic Drift",
        subtitle = "2026 · Science Fiction",
        summary = "A quiet signal pulls a survey crew beyond the mapped edge of the solar system.",
        mediaType = "movie",
        progressPercent = 42.0,
        durationMs = 6_960_000,
        viewOffsetMs = 2_923_000,
        artworkResource = R.drawable.demo_cosmic_drift,
    )
    private val afterMidnight = MediaItem(
        id = "demo-after-midnight",
        title = "After Midnight",
        subtitle = "2025 · Mystery",
        summary = "A late-night radio host follows a caller's clues through a city that should be asleep.",
        mediaType = "movie",
        artworkResource = R.drawable.demo_after_midnight,
    )
    private val harborStreet = MediaItem(
        id = "demo-harbor-street",
        title = "Harbor Street",
        subtitle = "S2 E4 · The Long Way Home",
        mediaType = "episode",
        progressPercent = 18.0,
        artworkResource = R.drawable.demo_harbor_street,
    )
    private val longWinter = MediaItem(
        id = "demo-long-winter",
        title = "The Long Winter",
        subtitle = "2024 · Drama",
        mediaType = "movie",
        artworkResource = R.drawable.demo_the_long_winter,
    )
    private val neonNights = MediaItem(
        id = "demo-neon-nights",
        title = "Neon Nights",
        subtitle = "S1 E8 · Last Train",
        mediaType = "episode",
        artworkResource = R.drawable.demo_neon_nights,
    )
    private val northernLights = MediaItem(
        id = "demo-northern-lights",
        title = "Northern Lights",
        subtitle = "2026 · Documentary",
        mediaType = "movie",
        artworkResource = R.drawable.demo_northern_lights,
    )

    val home = PlayerHome(
        serverName = "Tater Tube Demo",
        capabilities = PlayerCapabilities(
            localMedia = true,
            newznab = true,
            tubeTV = true,
            commercials = true,
            taterLink = true,
        ),
        hero = HomeHero(
            eyebrow = "Everything good, right where you left it",
            message = "A few favorites, a little live TV, and plenty worth discovering.",
        ),
        continueWatching = listOf(cosmicDrift, harborStreet, neonNights),
        recentlyAdded = listOf(afterMidnight, longWinter, northernLights, cosmicDrift, neonNights),
        liveChannels = listOf(
            MediaItem(
                id = "demo-channel-1",
                title = "Creature Features",
                subtitle = "CH 04 · The Midnight Visitor",
                mediaType = "channel",
                artworkResource = R.drawable.demo_creature_features,
            ),
            MediaItem(
                id = "demo-channel-2",
                title = "Saturday Cartoons",
                subtitle = "CH 08 · Galaxy Rangers",
                mediaType = "channel",
                artworkResource = R.drawable.demo_cartoon_channel,
            ),
        ),
    )

    val libraryRows = listOf(
        LibraryRow(
            title = "Continue Watching",
            entry = LibraryEntry("continue", "Continue Watching", "continue"),
            items = home.continueWatching,
        ),
        LibraryRow(
            title = "Recently Added",
            entry = LibraryEntry("local-discover:recent", "Recently Added", "localDiscover"),
            items = home.recentlyAdded,
        ),
    )

    private val demoTitles = listOf(cosmicDrift, afterMidnight, harborStreet, longWinter, neonNights, northernLights)

    fun libraryPage(location: LibraryLocation): LibraryPage = LibraryPage(
        title = location.title,
        items = when (location.categoryId) {
            "continue" -> home.continueWatching
            "local-discover:movies" -> demoTitles.filterNot { it.isEpisode }
            "local-discover:series" -> demoTitles.filter { it.isEpisode }
            else -> demoTitles
        },
    )

    val discoveryCategories = listOf(
        DiscoverCategory("movie:top", "Popular Movies", "What everyone is watching", category = "movie"),
        DiscoverCategory("movie:year:2026", "New Movies", "Fresh arrivals", category = "movie"),
        DiscoverCategory("movie:imdbrating", "Featured Movies", "Highly rated picks", category = "movie"),
        DiscoverCategory("series:top", "Popular TV", "Series worth starting", category = "series"),
        DiscoverCategory("series:year:2026", "New TV", "New seasons and premieres", category = "series"),
        DiscoverCategory("series:imdbrating", "Featured TV", "Critically loved television", category = "series"),
    )

    fun discoveryPage(category: DiscoverCategory): LibraryPage = LibraryPage(
        title = category.title,
        items = if (category.category == "series") listOf(harborStreet, neonNights) else
            listOf(cosmicDrift, afterMidnight, longWinter, northernLights),
    )

    fun discoverySearchResults(item: MediaItem): LibraryPage = LibraryPage(
        title = "Choose a release",
        items = listOf(
            item.copy(
                id = "${item.id}:release:1",
                title = "${item.title}.2026.2160p.WEB-DL.DDP5.1.H.265-TATER",
                subtitle = "18.4 GB",
                sizeText = "18.4 GB",
                files = "1",
                grabs = "204",
                nzbUrl = "demo://release/1",
            ),
            item.copy(
                id = "${item.id}:release:2",
                title = "${item.title}.2026.1080p.WEB.H264-TUBE",
                subtitle = "7.8 GB",
                sizeText = "7.8 GB",
                files = "1",
                grabs = "118",
                nzbUrl = "demo://release/2",
            ),
        ),
    )

    val recommendations = Recommendations(
        batch = RecommendationBatch(
            id = "demo-picks",
            assistantName = "Tater",
            summary = "A little mystery, a little wonder, and one cozy favorite for tonight.",
            picksBriefing = "I picked a few stories that fit the pace of what you have been watching.",
        ),
        items = listOf(cosmicDrift, afterMidnight, longWinter, harborStreet).mapIndexed { index, item ->
            RecommendationItem(
                id = "demo-pick-${index + 1}",
                rank = index + 1,
                title = item.title,
                mediaType = item.mediaType,
                reason = when (index) {
                    0 -> "You have been leaning toward quiet science fiction with a little mystery."
                    1 -> "A late-night mystery fits nicely beside your recent thrillers."
                    2 -> "This is a slower, warmer change of pace without leaving drama behind."
                    else -> "A short episode makes this an easy pick when you do not want a full movie."
                },
                launch = item,
            )
        },
    )

    val liveGuide = LiveGuide(
        channels = listOf(
            LiveChannel(
                id = "demo-guide-4",
                number = "04",
                title = "Creature Features",
                logoTitle = "Creature Features",
                now = LiveProgram(
                    id = "demo-program-1",
                    title = "The Midnight Visitor",
                    mediaType = "movie",
                    start = 0.0,
                    end = 5400.0,
                    duration = 5400.0,
                    progressPercent = 42.0,
                    poster = "",
                ),
                next = LiveProgram("demo-program-2", "After Midnight", mediaType = "movie", start = 5400.0, end = 10800.0),
                schedule = listOf(
                    LiveProgram("demo-program-1", "The Midnight Visitor", mediaType = "movie", start = 0.0, end = 5400.0, progressPercent = 42.0),
                    LiveProgram("demo-break", "Tater Break", kind = "commercial", start = 5400.0, end = 5580.0),
                    LiveProgram("demo-program-2", "After Midnight", mediaType = "movie", start = 5580.0, end = 10800.0),
                    LiveProgram("demo-program-3", "Cosmic Drift", mediaType = "movie", start = 10800.0, end = 16200.0),
                ),
            ),
            LiveChannel(
                id = "demo-guide-8",
                number = "08",
                title = "Saturday Cartoons",
                logoTitle = "Saturday Cartoons",
                now = LiveProgram("demo-cartoon-1", "Galaxy Rangers", mediaType = "episode", start = 0.0, end = 1800.0),
                next = LiveProgram("demo-cartoon-2", "Rocket Pals", mediaType = "episode", start = 1800.0, end = 3600.0),
            ),
        ),
    )
}
