package com.tatertotterson.tatertubeplayer.data

import org.junit.Assert.assertEquals
import org.junit.Test

class DemoCatalogTest {
    @Test
    fun bundledPlaybackPlanUsesASeekableUniversalFormat() {
        val plan = DemoCatalog.playbackPlan("android.resource://example/raw/tater_demo_reel")

        assertEquals("direct", plan.mode)
        assertEquals("mp4", plan.outputContainer)
        assertEquals("h264", plan.videoCodec)
        assertEquals("aac", plan.audioCodec)
        assertEquals(2, plan.outputAudioChannels)
        assertEquals(24.0, plan.source.durationSeconds ?: 0.0, 0.001)
    }
}
