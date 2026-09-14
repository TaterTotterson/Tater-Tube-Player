package com.tatertotterson.tatertubeplayer.data

import android.content.Context
import android.hardware.display.DisplayManager
import android.media.AudioDeviceInfo
import android.media.AudioFormat
import android.media.AudioManager
import android.media.MediaCodecList
import android.os.Build
import android.view.Display
import kotlin.math.roundToInt

object DeviceCapabilities {
    @Suppress("DEPRECATION")
    fun read(context: Context): PlaybackCapabilities {
        val display = context.getSystemService(DisplayManager::class.java).displays.firstOrNull()
        val mode = display?.mode
        val width = mode?.physicalWidth ?: 1920
        val height = mode?.physicalHeight ?: 1080
        val decoderTypes = MediaCodecList(MediaCodecList.ALL_CODECS).codecInfos
            .asSequence()
            .filter { !it.isEncoder }
            .flatMap { it.supportedTypes.asSequence() }
            .map { it.lowercase() }
            .toSet()

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
            if ("audio/flac" in decoderTypes) add("flac")
            if ("audio/opus" in decoderTypes) add("opus")
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
        val maxChannels = outputs.flatMap { it.channelCounts.asIterable() }.maxOrNull()?.coerceAtLeast(2) ?: 2

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
