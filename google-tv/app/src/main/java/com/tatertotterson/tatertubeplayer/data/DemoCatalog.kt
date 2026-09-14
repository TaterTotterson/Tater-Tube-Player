package com.tatertotterson.tatertubeplayer.data

import com.tatertotterson.tatertubeplayer.R
import com.tatertotterson.tatertubeplayer.model.HomeHero
import com.tatertotterson.tatertubeplayer.model.MediaItem
import com.tatertotterson.tatertubeplayer.model.PlayerCapabilities
import com.tatertotterson.tatertubeplayer.model.PlayerHome

object DemoCatalog {
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
}
