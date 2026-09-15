package com.tatertotterson.tatertubeplayer.data

import android.content.Context
import android.hardware.display.DisplayManager
import android.media.AudioDeviceInfo
import android.media.AudioFormat
import android.media.AudioManager
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.os.Build
import android.view.Display
import kotlin.math.roundToInt

object DeviceCapabilities {
    private val panelSizeProperties = listOf("sys.display-size", "vendor.display-size")

    @Suppress("DEPRECATION")
    fun read(context: Context): PlaybackCapabilities {
        val displayManager = context.getSystemService(DisplayManager::class.java)
        val display = displayManager.getDisplay(Display.DEFAULT_DISPLAY)
            ?: displayManager.displays.firstOrNull()
        val mode = display?.mode
        val displaySize = bestPhysicalDisplaySize(
            modeSizes = buildList {
                display?.supportedModes.orEmpty().forEach {
                    add(PhysicalDisplaySize(it.physicalWidth, it.physicalHeight))
                }
                mode?.let { add(PhysicalDisplaySize(it.physicalWidth, it.physicalHeight)) }
            },
            propertyValues = panelSizeProperties.mapNotNull(::readSystemProperty),
        )
        val width = displaySize.width
        val height = displaySize.height
        val decoderInfos = MediaCodecList(MediaCodecList.ALL_CODECS).codecInfos
            .filter { !it.isEncoder }
        val decoderTypes = decoderInfos.asSequence()
            .flatMap { it.supportedTypes.asSequence() }
            .map { it.lowercase() }
            .toSet()
        val videoDecoders = readVideoDecoderCapabilities(decoderInfos)

        val videoCodecs = buildList {
            if ("video/avc" in decoderTypes) add("h264")
            if ("video/hevc" in decoderTypes) add("hevc")
            if ("video/x-vnd.on2.vp9" in decoderTypes) add("vp9")
            if ("video/av01" in decoderTypes) add("av1")
        }.ifEmpty { listOf("h264") }

        val audioCodecs = buildList {
            add("aac")
            if ("audio/ac3" in decoderTypes) add("ac3")
            if ("audio/eac3" in decoderTypes || "audio/eac3-joc" in decoderTypes) add("eac3")
            if ("audio/vnd.dts" in decoderTypes) add("dts")
            if ("audio/vnd.dts.hd" in decoderTypes) add("dts_hd")
            if ("audio/true-hd" in decoderTypes) add("truehd")
            if ("audio/flac" in decoderTypes) add("flac")
            if ("audio/opus" in decoderTypes) add("opus")
            if ("audio/vorbis" in decoderTypes) add("vorbis")
            if ("audio/alac" in decoderTypes || "audio/x-alac" in decoderTypes) add("alac")
            if ("audio/mpeg" in decoderTypes) add("mp3")
        }.distinct()

        val audioManager = context.getSystemService(AudioManager::class.java)
        val outputs = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
        val theaterOutputs = outputs.filter { it.isTheaterOutput() }
        val encodings = theaterOutputs.flatMap { it.encodings.asIterable() }.toSet()
        val passthrough = buildList {
            if (AudioFormat.ENCODING_AC3 in encodings) add("ac3")
            if (AudioFormat.ENCODING_E_AC3 in encodings) add("eac3")
            if (AudioFormat.ENCODING_DTS in encodings) add("dts")
            if (AudioFormat.ENCODING_DTS_HD in encodings) add("dts_hd")
            if (AudioFormat.ENCODING_DOLBY_TRUEHD in encodings) add("truehd")
        }
        val maxChannels = bestNativeAudioChannelCount(
            theaterOutputs.flatMap { it.channelCounts.asIterable() },
        )

        val hdrFormats = if (Build.VERSION.SDK_INT >= 24) {
            display?.hdrCapabilities?.supportedHdrTypes?.toList().orEmpty().mapNotNull { it.hdrName() }.distinct()
        } else {
            emptyList()
        }
        val hasDolbyVisionDecoder = "video/dolby-vision" in decoderTypes
        val supportsHdr10 = "hdr10" in hdrFormats && "hevc" in videoCodecs
        val refreshRate = mode?.refreshRate?.toDouble()?.takeIf { it > 0 }

        return PlaybackCapabilities(
            videoCodecs = videoCodecs,
            videoDecoders = videoDecoders,
            audioCodecs = audioCodecs,
            audioPassthrough = passthrough,
            videoHdrFormats = hdrFormats,
            displayHdrFormats = hdrFormats,
            displayHdrEnabled = hdrFormats.isNotEmpty(),
            maxVideoBitDepth = if (hdrFormats.isEmpty()) 8 else 10,
            dolbyVisionProfiles = if ("dolby_vision" in hdrFormats && hasDolbyVisionDecoder) listOf(5, 8) else emptyList(),
            maxWidth = maxOf(width, height),
            maxHeight = minOf(width, height),
            maxAudioChannels = maxChannels,
            outputName = "${Build.MANUFACTURER} ${Build.MODEL}".trim(),
            outputConnection = if (theaterOutputs.isEmpty()) "device" else "hdmi",
            tubeTvOutputVideoRange = if (supportsHdr10) "hdr10" else "sdr",
            tubeTvOutputFrameRate = refreshRate?.broadcastRate(),
        )
    }

    private fun readSystemProperty(name: String): String? = runCatching {
        ProcessBuilder("/system/bin/getprop", name)
            .redirectErrorStream(true)
            .start()
            .inputStream
            .bufferedReader()
            .use { it.readLine()?.trim() }
            ?.takeIf { it.isNotEmpty() }
    }.getOrNull()

    private fun readVideoDecoderCapabilities(
        decoderInfos: List<MediaCodecInfo>,
    ): List<VideoDecoderCapability> = decoderInfos.flatMap { decoder ->
        decoder.supportedTypes.mapNotNull { advertisedType ->
            val mimeType = advertisedType.lowercase()
            val codec = androidVideoCodecName(mimeType) ?: return@mapNotNull null
            val codecCapabilities = runCatching {
                decoder.getCapabilitiesForType(advertisedType)
            }.getOrNull() ?: return@mapNotNull null
            val performanceLimits = codecCapabilities.videoCapabilities
                ?.let(::androidVideoPerformanceLimits)
                .orEmpty()
            val hardwareAccelerated = if (Build.VERSION.SDK_INT >= 29) {
                decoder.isHardwareAccelerated
            } else {
                !decoder.name.lowercase().let { it.startsWith("omx.google.") || it.startsWith("c2.android.") }
            }
            val profileLimits = codecCapabilities.profileLevels
                .mapNotNull { profileLevel ->
                    val profile = androidVideoProfileName(mimeType, profileLevel.profile)
                        ?: return@mapNotNull null
                    VideoDecoderCapability(
                        codec = codec,
                        profile = profile,
                        maxLevel = androidVideoLevel(mimeType, profileLevel.level),
                        maxBitDepth = androidVideoProfileBitDepth(mimeType, profileLevel.profile),
                        hardwareAccelerated = hardwareAccelerated,
                        performanceLimits = performanceLimits,
                    )
                }
                .groupBy { it.profile }
                .map { (_, profiles) ->
                    profiles.maxWithOrNull(
                        compareBy<VideoDecoderCapability> { it.maxLevel }
                            .thenBy { it.maxBitDepth },
                    )!!.copy(
                        maxLevel = profiles.maxOf { it.maxLevel },
                        maxBitDepth = profiles.maxOf { it.maxBitDepth },
                    )
                }
            profileLimits.ifEmpty {
                listOf(
                    VideoDecoderCapability(
                        codec = codec,
                        profile = "",
                        maxLevel = 0,
                        maxBitDepth = 0,
                        hardwareAccelerated = hardwareAccelerated,
                        performanceLimits = performanceLimits,
                    ),
                )
            }
        }.flatten()
    }

    private fun AudioDeviceInfo.isTheaterOutput(): Boolean = type == AudioDeviceInfo.TYPE_HDMI ||
        (Build.VERSION.SDK_INT >= 29 && type == AudioDeviceInfo.TYPE_HDMI_ARC) ||
        (Build.VERSION.SDK_INT >= 31 && type == AudioDeviceInfo.TYPE_HDMI_EARC)

    private fun Int.hdrName(): String? = when (this) {
        Display.HdrCapabilities.HDR_TYPE_HDR10 -> "hdr10"
        Display.HdrCapabilities.HDR_TYPE_HLG -> "hlg"
        Display.HdrCapabilities.HDR_TYPE_DOLBY_VISION -> "dolby_vision"
        Display.HdrCapabilities.HDR_TYPE_HDR10_PLUS -> "hdr10_plus"
        else -> null
    }

    private fun Double.broadcastRate(): Double {
        val rounded = roundToInt()
        return when {
            rounded >= 59 -> 60_000.0 / 1_001.0
            rounded >= 49 -> 50.0
            rounded >= 29 -> 30_000.0 / 1_001.0
            rounded >= 24 -> 24.0
            else -> 23_976.0 / 1_000.0
        }
    }
}

private val androidVideoSizes = listOf(
    PhysicalDisplaySize(640, 360),
    PhysicalDisplaySize(720, 480),
    PhysicalDisplaySize(720, 576),
    PhysicalDisplaySize(1280, 720),
    PhysicalDisplaySize(1920, 1080),
    PhysicalDisplaySize(2560, 1440),
    PhysicalDisplaySize(3840, 2160),
    PhysicalDisplaySize(4096, 2160),
    PhysicalDisplaySize(7680, 4320),
)

private val androidVideoFrameRates = listOf(120.0, 100.0, 60.0, 50.0, 30.0, 25.0, 24.0)

private fun androidVideoPerformanceLimits(
    capabilities: MediaCodecInfo.VideoCapabilities,
): List<VideoPerformanceLimit> {
    val supported = androidVideoSizes.mapNotNull { size ->
        val frameRate = androidVideoFrameRates.firstOrNull { rate ->
            runCatching {
                capabilities.areSizeAndRateSupported(size.landscapeWidth, size.landscapeHeight, rate)
            }.getOrDefault(false)
        }
        when {
            frameRate != null -> VideoPerformanceLimit(size.landscapeWidth, size.landscapeHeight, frameRate)
            runCatching {
                capabilities.isSizeSupported(size.landscapeWidth, size.landscapeHeight)
            }.getOrDefault(false) -> VideoPerformanceLimit(size.landscapeWidth, size.landscapeHeight, 0.0)
            else -> null
        }
    }
    return supported.filter { candidate ->
        supported.none { other ->
            other !== candidate &&
                other.maxWidth >= candidate.maxWidth &&
                other.maxHeight >= candidate.maxHeight &&
                (candidate.maxFrameRate <= 0 || other.maxFrameRate >= candidate.maxFrameRate)
        }
    }
}

internal fun androidVideoCodecName(mimeType: String): String? = when (mimeType.lowercase()) {
    "video/avc" -> "h264"
    "video/hevc" -> "hevc"
    "video/x-vnd.on2.vp9" -> "vp9"
    "video/av01" -> "av1"
    else -> null
}

internal fun androidVideoProfileName(mimeType: String, profile: Int): String? = when (mimeType.lowercase()) {
    "video/avc" -> when (profile) {
        MediaCodecInfo.CodecProfileLevel.AVCProfileBaseline -> "baseline"
        MediaCodecInfo.CodecProfileLevel.AVCProfileConstrainedBaseline -> "constrained_baseline"
        MediaCodecInfo.CodecProfileLevel.AVCProfileMain -> "main"
        MediaCodecInfo.CodecProfileLevel.AVCProfileExtended -> "extended"
        MediaCodecInfo.CodecProfileLevel.AVCProfileHigh -> "high"
        MediaCodecInfo.CodecProfileLevel.AVCProfileConstrainedHigh -> "constrained_high"
        MediaCodecInfo.CodecProfileLevel.AVCProfileHigh10 -> "high_10"
        MediaCodecInfo.CodecProfileLevel.AVCProfileHigh422 -> "high_422"
        MediaCodecInfo.CodecProfileLevel.AVCProfileHigh444 -> "high_444"
        else -> null
    }
    "video/hevc" -> when (profile) {
        MediaCodecInfo.CodecProfileLevel.HEVCProfileMain -> "main"
        MediaCodecInfo.CodecProfileLevel.HEVCProfileMain10,
        MediaCodecInfo.CodecProfileLevel.HEVCProfileMain10HDR10,
        MediaCodecInfo.CodecProfileLevel.HEVCProfileMain10HDR10Plus -> "main_10"
        MediaCodecInfo.CodecProfileLevel.HEVCProfileMainStill -> "main_still_picture"
        MediaCodecInfo.CodecProfileLevel.HEVCProfileMain400 -> "main_400"
        MediaCodecInfo.CodecProfileLevel.HEVCProfileMain444 -> "main_444"
        else -> null
    }
    "video/x-vnd.on2.vp9" -> when (profile) {
        MediaCodecInfo.CodecProfileLevel.VP9Profile0 -> "profile_0"
        MediaCodecInfo.CodecProfileLevel.VP9Profile1 -> "profile_1"
        MediaCodecInfo.CodecProfileLevel.VP9Profile2,
        MediaCodecInfo.CodecProfileLevel.VP9Profile2HDR,
        MediaCodecInfo.CodecProfileLevel.VP9Profile2HDR10Plus -> "profile_2"
        MediaCodecInfo.CodecProfileLevel.VP9Profile3,
        MediaCodecInfo.CodecProfileLevel.VP9Profile3HDR,
        MediaCodecInfo.CodecProfileLevel.VP9Profile3HDR10Plus -> "profile_3"
        else -> null
    }
    "video/av01" -> when (profile) {
        MediaCodecInfo.CodecProfileLevel.AV1ProfileMain8,
        MediaCodecInfo.CodecProfileLevel.AV1ProfileMain10,
        MediaCodecInfo.CodecProfileLevel.AV1ProfileMain10HDR10,
        MediaCodecInfo.CodecProfileLevel.AV1ProfileMain10HDR10Plus -> "main"
        else -> null
    }
    else -> null
}

internal fun androidVideoProfileBitDepth(mimeType: String, profile: Int): Int = when (mimeType.lowercase()) {
    "video/avc" -> when (profile) {
        MediaCodecInfo.CodecProfileLevel.AVCProfileHigh10,
        MediaCodecInfo.CodecProfileLevel.AVCProfileHigh422,
        MediaCodecInfo.CodecProfileLevel.AVCProfileHigh444 -> 10
        else -> 8
    }
    "video/hevc" -> when (profile) {
        MediaCodecInfo.CodecProfileLevel.HEVCProfileMain10,
        MediaCodecInfo.CodecProfileLevel.HEVCProfileMain10HDR10,
        MediaCodecInfo.CodecProfileLevel.HEVCProfileMain10HDR10Plus -> 10
        else -> 8
    }
    "video/x-vnd.on2.vp9" -> when (profile) {
        MediaCodecInfo.CodecProfileLevel.VP9Profile2,
        MediaCodecInfo.CodecProfileLevel.VP9Profile2HDR,
        MediaCodecInfo.CodecProfileLevel.VP9Profile2HDR10Plus,
        MediaCodecInfo.CodecProfileLevel.VP9Profile3,
        MediaCodecInfo.CodecProfileLevel.VP9Profile3HDR,
        MediaCodecInfo.CodecProfileLevel.VP9Profile3HDR10Plus -> 10
        else -> 8
    }
    "video/av01" -> when (profile) {
        MediaCodecInfo.CodecProfileLevel.AV1ProfileMain10,
        MediaCodecInfo.CodecProfileLevel.AV1ProfileMain10HDR10,
        MediaCodecInfo.CodecProfileLevel.AV1ProfileMain10HDR10Plus -> 10
        else -> 8
    }
    else -> 0
}

internal fun androidVideoLevel(mimeType: String, level: Int): Int = when (mimeType.lowercase()) {
    "video/avc" -> androidAVCLevel(level)
    "video/hevc" -> androidHEVCLevel(level)
    "video/x-vnd.on2.vp9" -> androidVP9Level(level)
    "video/av01" -> androidAV1Level(level)
    else -> 0
}

private fun androidAVCLevel(level: Int): Int = when (level) {
    MediaCodecInfo.CodecProfileLevel.AVCLevel1 -> 10
    MediaCodecInfo.CodecProfileLevel.AVCLevel1b -> 9
    MediaCodecInfo.CodecProfileLevel.AVCLevel11 -> 11
    MediaCodecInfo.CodecProfileLevel.AVCLevel12 -> 12
    MediaCodecInfo.CodecProfileLevel.AVCLevel13 -> 13
    MediaCodecInfo.CodecProfileLevel.AVCLevel2 -> 20
    MediaCodecInfo.CodecProfileLevel.AVCLevel21 -> 21
    MediaCodecInfo.CodecProfileLevel.AVCLevel22 -> 22
    MediaCodecInfo.CodecProfileLevel.AVCLevel3 -> 30
    MediaCodecInfo.CodecProfileLevel.AVCLevel31 -> 31
    MediaCodecInfo.CodecProfileLevel.AVCLevel32 -> 32
    MediaCodecInfo.CodecProfileLevel.AVCLevel4 -> 40
    MediaCodecInfo.CodecProfileLevel.AVCLevel41 -> 41
    MediaCodecInfo.CodecProfileLevel.AVCLevel42 -> 42
    MediaCodecInfo.CodecProfileLevel.AVCLevel5 -> 50
    MediaCodecInfo.CodecProfileLevel.AVCLevel51 -> 51
    MediaCodecInfo.CodecProfileLevel.AVCLevel52 -> 52
    MediaCodecInfo.CodecProfileLevel.AVCLevel6 -> 60
    MediaCodecInfo.CodecProfileLevel.AVCLevel61 -> 61
    MediaCodecInfo.CodecProfileLevel.AVCLevel62 -> 62
    else -> 0
}

private fun androidHEVCLevel(level: Int): Int = when (level) {
    MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel1,
    MediaCodecInfo.CodecProfileLevel.HEVCHighTierLevel1 -> 30
    MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel2,
    MediaCodecInfo.CodecProfileLevel.HEVCHighTierLevel2 -> 60
    MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel21,
    MediaCodecInfo.CodecProfileLevel.HEVCHighTierLevel21 -> 63
    MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel3,
    MediaCodecInfo.CodecProfileLevel.HEVCHighTierLevel3 -> 90
    MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel31,
    MediaCodecInfo.CodecProfileLevel.HEVCHighTierLevel31 -> 93
    MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel4,
    MediaCodecInfo.CodecProfileLevel.HEVCHighTierLevel4 -> 120
    MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel41,
    MediaCodecInfo.CodecProfileLevel.HEVCHighTierLevel41 -> 123
    MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel5,
    MediaCodecInfo.CodecProfileLevel.HEVCHighTierLevel5 -> 150
    MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel51,
    MediaCodecInfo.CodecProfileLevel.HEVCHighTierLevel51 -> 153
    MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel52,
    MediaCodecInfo.CodecProfileLevel.HEVCHighTierLevel52 -> 156
    MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel6,
    MediaCodecInfo.CodecProfileLevel.HEVCHighTierLevel6 -> 180
    MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel61,
    MediaCodecInfo.CodecProfileLevel.HEVCHighTierLevel61 -> 183
    MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel62,
    MediaCodecInfo.CodecProfileLevel.HEVCHighTierLevel62 -> 186
    else -> 0
}

private fun androidVP9Level(level: Int): Int = when (level) {
    MediaCodecInfo.CodecProfileLevel.VP9Level1 -> 10
    MediaCodecInfo.CodecProfileLevel.VP9Level11 -> 11
    MediaCodecInfo.CodecProfileLevel.VP9Level2 -> 20
    MediaCodecInfo.CodecProfileLevel.VP9Level21 -> 21
    MediaCodecInfo.CodecProfileLevel.VP9Level3 -> 30
    MediaCodecInfo.CodecProfileLevel.VP9Level31 -> 31
    MediaCodecInfo.CodecProfileLevel.VP9Level4 -> 40
    MediaCodecInfo.CodecProfileLevel.VP9Level41 -> 41
    MediaCodecInfo.CodecProfileLevel.VP9Level5 -> 50
    MediaCodecInfo.CodecProfileLevel.VP9Level51 -> 51
    MediaCodecInfo.CodecProfileLevel.VP9Level52 -> 52
    MediaCodecInfo.CodecProfileLevel.VP9Level6 -> 60
    MediaCodecInfo.CodecProfileLevel.VP9Level61 -> 61
    MediaCodecInfo.CodecProfileLevel.VP9Level62 -> 62
    else -> 0
}

private fun androidAV1Level(level: Int): Int = when (level) {
    MediaCodecInfo.CodecProfileLevel.AV1Level2 -> 0
    MediaCodecInfo.CodecProfileLevel.AV1Level21 -> 1
    MediaCodecInfo.CodecProfileLevel.AV1Level22 -> 2
    MediaCodecInfo.CodecProfileLevel.AV1Level23 -> 3
    MediaCodecInfo.CodecProfileLevel.AV1Level3 -> 4
    MediaCodecInfo.CodecProfileLevel.AV1Level31 -> 5
    MediaCodecInfo.CodecProfileLevel.AV1Level32 -> 6
    MediaCodecInfo.CodecProfileLevel.AV1Level33 -> 7
    MediaCodecInfo.CodecProfileLevel.AV1Level4 -> 8
    MediaCodecInfo.CodecProfileLevel.AV1Level41 -> 9
    MediaCodecInfo.CodecProfileLevel.AV1Level42 -> 10
    MediaCodecInfo.CodecProfileLevel.AV1Level43 -> 11
    MediaCodecInfo.CodecProfileLevel.AV1Level5 -> 12
    MediaCodecInfo.CodecProfileLevel.AV1Level51 -> 13
    MediaCodecInfo.CodecProfileLevel.AV1Level52 -> 14
    MediaCodecInfo.CodecProfileLevel.AV1Level53 -> 15
    MediaCodecInfo.CodecProfileLevel.AV1Level6 -> 16
    MediaCodecInfo.CodecProfileLevel.AV1Level61 -> 17
    MediaCodecInfo.CodecProfileLevel.AV1Level62 -> 18
    MediaCodecInfo.CodecProfileLevel.AV1Level63 -> 19
    MediaCodecInfo.CodecProfileLevel.AV1Level7 -> 20
    MediaCodecInfo.CodecProfileLevel.AV1Level71 -> 21
    MediaCodecInfo.CodecProfileLevel.AV1Level72 -> 22
    MediaCodecInfo.CodecProfileLevel.AV1Level73 -> 23
    else -> 0
}

internal data class PhysicalDisplaySize(val width: Int, val height: Int) {
    val landscapeWidth: Int get() = maxOf(width, height)
    val landscapeHeight: Int get() = minOf(width, height)
    val pixels: Long get() = landscapeWidth.toLong() * landscapeHeight.toLong()
}

internal fun parsePhysicalDisplaySize(value: String): PhysicalDisplaySize? {
    val match = Regex("^\\s*(\\d{3,5})\\s*[xX]\\s*(\\d{3,5})\\s*$").matchEntire(value)
        ?: return null
    val width = match.groupValues[1].toIntOrNull() ?: return null
    val height = match.groupValues[2].toIntOrNull() ?: return null
    if (width <= 0 || height <= 0) return null
    return PhysicalDisplaySize(maxOf(width, height), minOf(width, height))
}

internal fun bestPhysicalDisplaySize(
    modeSizes: List<PhysicalDisplaySize>,
    propertyValues: List<String>,
): PhysicalDisplaySize {
    val candidates = buildList {
        addAll(modeSizes.filter { it.width > 0 && it.height > 0 })
        propertyValues.mapNotNullTo(this, ::parsePhysicalDisplaySize)
    }
    return candidates.maxWithOrNull(
        compareBy<PhysicalDisplaySize> { it.pixels }
            .thenBy { it.landscapeWidth }
            .thenBy { it.landscapeHeight },
    )?.let { PhysicalDisplaySize(it.landscapeWidth, it.landscapeHeight) }
        ?: PhysicalDisplaySize(1920, 1080)
}

internal fun bestNativeAudioChannelCount(theaterChannelCounts: List<Int>): Int =
    theaterChannelCounts.maxOrNull()?.coerceIn(2, 8) ?: 2
