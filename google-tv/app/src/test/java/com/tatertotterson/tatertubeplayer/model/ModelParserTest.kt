package com.tatertotterson.tatertubeplayer.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ModelParserTest {
    @Test
    fun parsesHierarchicalLibraryRows() {
        val rows = ModelParser.libraryRows(
            """{"success":true,"data":{"rows":[{"title":"Shows","entry":{"id":"local:tv","title":"Shows","type":"local"},"items":[{"id":"show-1","title":"Thirty Rocks","mediaType":"show","categoryId":"local:tv","path":"Thirty Rocks","seasonCount":7}]}]}}"""
        )

        assertEquals("local:tv", rows.single().entry.id)
        assertEquals(7, rows.single().items.single().seasonCount)
        assertTrue(rows.single().items.single().isBrowsable)
    }

    @Test
    fun extractsDiscoverRootCategories() {
        val categories = ModelParser.discoverCategories(
            """{"data":{"categories":[{"id":"stream","title":"Stream","children":[{"id":"discover","title":"Discover","type":"discoverRoot","children":[{"id":"movie:top","title":"Popular Movies","category":"movie"}]}]}]}}"""
        )

        assertEquals("movie:top", categories.single().id)
        assertEquals("popular-movies", categories.single().artworkKey)
    }

    @Test
    fun groupsInterstitialsInGuide() {
        val guide = ModelParser.liveGuide(
            """{"data":{"startedAt":"2026-09-13T12:00:00Z","serverNow":"2026-09-13T12:10:00Z","channels":[{"id":"7","number":"07","title":"Sci-Fi","streamUrl":"/live/7","schedule":[{"title":"Movie","kind":"movie","start":0,"end":500},{"title":"Ad","kind":"commercial","start":500,"end":560},{"title":"Bumper","kind":"bumper","start":560,"end":600},{"title":"Next Movie","kind":"movie","start":600,"end":1200}]}]}}"""
        )

        val programs = guide.channels.single().displayedPrograms(550.0)
        assertEquals("Commercial Break", programs.first().title)
        assertEquals(100.0, programs.first().duration, 0.01)
        assertEquals("Next Movie", programs[1].title)
    }

    @Test
    fun parsesRecommendationLaunchAndPlaybackTracks() {
        val picks = ModelParser.recommendations(
            """{"data":{"batch":{"id":"batch-1","assistantName":"Tater","summary":"For Sunday morning"},"items":[{"id":"pick-1","rank":1,"title":"Cartoon Hour","reason":"Weekend cartoons","launch":{"id":"episode-1","title":"Cartoon Hour","mediaType":"episode","streamUrl":"/play/1"}}]}}"""
        )
        val plan = ModelParser.playbackPlan(
            """{"data":{"streamUrl":"/session/1.m3u8","videoMode":"direct","audioMode":"transcode","selectedAudioTrack":1,"source":{"durationSeconds":1800,"audioTracks":[{"index":0,"codec":"aac","channels":2,"language":"eng"},{"index":1,"codec":"eac3","channels":6,"language":"eng","default":true}]}}}"""
        )

        assertEquals("Cartoon Hour", picks.items.single().launch.title)
        assertEquals(2, plan.source.audioTracks.size)
        assertEquals(6, plan.source.audioTracks[1].channels)
    }

    @Test
    fun parsesNextEpisodeAndConvertsDurationSeconds() {
        val next = ModelParser.nextEpisode(
            """{"data":{"item":{"id":"episode-2","title":"The Next One","mediaType":"episode","categoryId":"local:tv","path":"Show/Season 1/Episode 2.mkv","streamUrl":"/play/2","duration":1320}}}"""
        )

        assertEquals("episode-2", next?.id)
        assertEquals(1_320_000L, next?.durationMs)
    }
}
