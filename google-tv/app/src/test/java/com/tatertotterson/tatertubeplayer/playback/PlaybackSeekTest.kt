package com.tatertotterson.tatertubeplayer.playback

import com.tatertotterson.tatertubeplayer.model.LiveChannel
import com.tatertotterson.tatertubeplayer.model.LiveGuide
import com.tatertotterson.tatertubeplayer.model.LiveProgram
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PlaybackSeekTest {
    @Test
    fun seekUsesThePendingAbsolutePosition() {
        assertEquals(530_000, clampedSeekTarget(520_000, 10_000, 7_200_000))
        assertEquals(510_000, clampedSeekTarget(520_000, -10_000, 7_200_000))
    }

    @Test
    fun seekStaysInsideThePlayableSource() {
        assertEquals(0, clampedSeekTarget(5_000, -10_000, 60_000))
        assertEquals(59_000, clampedSeekTarget(58_000, 10_000, 60_000))
    }

    @Test
    fun tubeTvPlaybackDoesNotCreateASeekTarget() {
        assertEquals(null, playbackSeekTarget(true, 520_000, 10_000, 7_200_000))
        assertEquals(530_000L, playbackSeekTarget(false, 520_000, 10_000, 7_200_000))
    }

    @Test
    fun channelLogoIsHiddenForCommercialsAndBumpersOnly() {
        val guide = LiveGuide(channels = listOf(
            LiveChannel(
                id = "7",
                number = "7",
                title = "Movies",
                schedule = listOf(
                    LiveProgram("movie", "Movie", kind = "movie", start = 0.0, end = 60.0),
                    LiveProgram("commercial", "Commercial", kind = "commercial", start = 60.0, end = 90.0),
                    LiveProgram("bumper", "Tater Bumper", kind = "tater_bumper", start = 90.0, end = 100.0),
                    LiveProgram("next", "Next Movie", kind = "movie", start = 100.0, end = 200.0),
                ),
            ),
        ))

        assertFalse(channelProgramIsInterstitial(guide, "7", 30.0))
        assertTrue(channelProgramIsInterstitial(guide, "7", 75.0))
        assertTrue(channelProgramIsInterstitial(guide, "7", 95.0))
        assertFalse(channelProgramIsInterstitial(guide, "7", 120.0))
        assertFalse(channelProgramIsInterstitial(guide, "8", 75.0))
    }
}
