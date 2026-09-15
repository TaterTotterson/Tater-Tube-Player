package com.tatertotterson.tatertubeplayer.data

import android.media.MediaCodecInfo
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class DeviceCapabilitiesTest {
    @Test
    fun usesPhysicalPanelPropertyWhenTvOnlyReportsItsUiSurface() {
        assertEquals(
            PhysicalDisplaySize(3840, 2160),
            bestPhysicalDisplaySize(
                modeSizes = listOf(PhysicalDisplaySize(1920, 1080)),
                propertyValues = listOf("3840x2160"),
            ),
        )
    }

    @Test
    fun usesLargestPublicDisplayModeWhenItIsAvailable() {
        assertEquals(
            PhysicalDisplaySize(3840, 2160),
            bestPhysicalDisplaySize(
                modeSizes = listOf(
                    PhysicalDisplaySize(1920, 1080),
                    PhysicalDisplaySize(3840, 2160),
                ),
                propertyValues = emptyList(),
            ),
        )
    }

    @Test
    fun normalizesPortraitPropertiesAndIgnoresInvalidValues() {
        assertEquals(PhysicalDisplaySize(3840, 2160), parsePhysicalDisplaySize("2160 x 3840"))
        assertNull(parsePhysicalDisplaySize("auto"))
    }

    @Test
    fun fallsBackTo1080pWhenTheDeviceReportsNothingUsable() {
        assertEquals(
            PhysicalDisplaySize(1920, 1080),
            bestPhysicalDisplaySize(emptyList(), listOf("unknown")),
        )
    }

    @Test
    fun builtInTvSpeakersUseStereo() {
        assertEquals(2, bestNativeAudioChannelCount(emptyList()))
    }

    @Test
    fun connectedTheaterOutputPreservesSurround() {
        assertEquals(8, bestNativeAudioChannelCount(listOf(2, 6, 8)))
    }

    @Test
    fun normalizesAndroidVideoProfilesForTheServer() {
        assertEquals(
            "main_10",
            androidVideoProfileName(
                "video/hevc",
                MediaCodecInfo.CodecProfileLevel.HEVCProfileMain10HDR10,
            ),
        )
        assertEquals(
            "main",
            androidVideoProfileName(
                "video/av01",
                MediaCodecInfo.CodecProfileLevel.AV1ProfileMain10,
            ),
        )
    }

    @Test
    fun convertsAndroidLevelsToFfprobeValues() {
        assertEquals(
            153,
            androidVideoLevel(
                "video/hevc",
                MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel51,
            ),
        )
        assertEquals(
            41,
            androidVideoLevel(
                "video/avc",
                MediaCodecInfo.CodecProfileLevel.AVCLevel41,
            ),
        )
    }
}
