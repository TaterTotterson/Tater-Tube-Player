package com.tatertotterson.tatertubeplayer.playback

import android.app.Activity
import android.view.KeyEvent
import android.view.ViewGroup
import android.view.WindowManager
import androidx.activity.compose.BackHandler
import androidx.annotation.OptIn
import androidx.compose.foundation.background
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.viewinterop.AndroidView
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.Tracks
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.session.MediaSession
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import androidx.tv.material3.Text
import com.tatertotterson.tatertubeplayer.ui.PlaybackSession
import com.tatertotterson.tatertubeplayer.ui.components.GlassSurface
import com.tatertotterson.tatertubeplayer.ui.components.TaterArtwork
import com.tatertotterson.tatertubeplayer.ui.theme.TaterColors
import kotlinx.coroutines.delay

@OptIn(UnstableApi::class)
@Composable
fun PlaybackScreen(
    session: PlaybackSession,
    token: String?,
    onExit: (positionMs: Long, durationMs: Long, completed: Boolean) -> Unit,
    onAudioTrackChange: (trackIndex: Int, positionMs: Long) -> Unit,
) {
    val context = LocalContext.current
    val activity = context as? Activity
    var positionMs by remember(session.item.id) { mutableLongStateOf(session.startPositionMs) }
    var durationMs by remember(session.item.id) { mutableLongStateOf(session.item.durationMs) }
    var overlayVisible by remember(session.item.id) { mutableStateOf(true) }
    var errorMessage by remember(session.item.id) { mutableStateOf<String?>(null) }
    var hasExited by remember(session.item.id) { mutableStateOf(false) }
    var interactiveOverlay by remember(session.item.id) { mutableStateOf(false) }
    var selectedControl by remember(session.item.id) { mutableIntStateOf(0) }
    var audioOptions by remember(session.item.id) { mutableStateOf<List<TrackOption>>(emptyList()) }
    var subtitleOptions by remember(session.item.id) { mutableStateOf<List<TrackOption>>(emptyList()) }
    var audioLabel by remember(session.item.id) { mutableStateOf("AUTO") }
    var subtitleLabel by remember(session.item.id) { mutableStateOf("OFF") }
    val playbackFocus = remember(session.item.id) { FocusRequester() }

    val httpFactory = remember(token) {
        DefaultHttpDataSource.Factory().apply {
            if (!token.isNullOrBlank()) setDefaultRequestProperties(mapOf("Authorization" to "Bearer $token"))
            setConnectTimeoutMs(10_000)
            setReadTimeoutMs(60_000)
            setAllowCrossProtocolRedirects(false)
        }
    }
    val player = remember(session.plan.streamUrl, token) {
        val dataSource = DefaultDataSource.Factory(context, httpFactory)
        ExoPlayer.Builder(context)
            .setMediaSourceFactory(DefaultMediaSourceFactory(dataSource))
            .build()
            .apply {
                trackSelectionParameters = trackSelectionParameters.buildUpon()
                    .setPreferredAudioLanguage("en")
                    .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, true)
                    .build()
                setMediaItem(MediaItem.fromUri(session.plan.streamUrl), session.startPositionMs)
                prepare()
                playWhenReady = true
            }
    }
    val mediaSession = remember(player) { MediaSession.Builder(context, player).build() }

    fun updateTrackOptions(tracks: Tracks = player.currentTracks) {
        audioOptions = tracks.groups.trackOptions(C.TRACK_TYPE_AUDIO)
        subtitleOptions = tracks.groups.trackOptions(C.TRACK_TYPE_TEXT)
        audioLabel = audioOptions.firstOrNull { it.selected }?.label
            ?: session.plan.source.audioTracks.getOrNull(session.plan.selectedAudioTrack)?.displayLabel()
            ?: session.plan.audioCodec?.uppercase()
            ?: "AUTO"
        subtitleLabel = subtitleOptions.firstOrNull { it.selected }?.label ?: "OFF"
    }

    fun cycleAudio() {
        if (audioOptions.size > 1) {
            val selected = audioOptions.indexOfFirst { it.selected }
            val option = audioOptions[(selected + 1).mod(audioOptions.size)]
            player.trackSelectionParameters = player.trackSelectionParameters.buildUpon()
                .clearOverridesOfType(C.TRACK_TYPE_AUDIO)
                .setOverrideForType(TrackSelectionOverride(option.group.mediaTrackGroup, option.trackIndex))
                .build()
            audioLabel = option.label
            overlayVisible = true
            return
        }
        val sourceTracks = session.plan.source.audioTracks
        if (sourceTracks.size > 1) {
            val current = sourceTracks.indexOfFirst { it.index == session.plan.selectedAudioTrack }.coerceAtLeast(0)
            val next = sourceTracks[(current + 1) % sourceTracks.size]
            audioLabel = next.displayLabel()
            onAudioTrackChange(next.index, player.currentPosition.coerceAtLeast(0))
            overlayVisible = true
        }
    }

    fun cycleSubtitles() {
        if (subtitleOptions.isEmpty()) return
        val selected = subtitleOptions.indexOfFirst { it.selected }
        val builder = player.trackSelectionParameters.buildUpon().clearOverridesOfType(C.TRACK_TYPE_TEXT)
        if (selected >= subtitleOptions.lastIndex) {
            player.trackSelectionParameters = builder.setTrackTypeDisabled(C.TRACK_TYPE_TEXT, true).build()
            subtitleLabel = "OFF"
        } else {
            val next = selected + 1
            val option = subtitleOptions[next]
            player.trackSelectionParameters = builder
                .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, false)
                .setOverrideForType(TrackSelectionOverride(option.group.mediaTrackGroup, option.trackIndex))
                .build()
            subtitleLabel = option.label
        }
        overlayVisible = true
    }

    fun finish(completed: Boolean) {
        if (hasExited) return
        hasExited = true
        onExit(
            player.currentPosition.coerceAtLeast(0),
            player.duration.takeIf { it > 0 && it != C.TIME_UNSET } ?: durationMs,
            completed,
        )
    }

    DisposableEffect(player) {
        activity?.window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        val listener = object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) {
                if (playbackState == Player.STATE_ENDED) finish(completed = true)
            }

            override fun onPlayerError(error: PlaybackException) {
                errorMessage = error.localizedMessage ?: "Native playback stopped unexpectedly."
                overlayVisible = true
            }

            override fun onTracksChanged(tracks: Tracks) {
                updateTrackOptions(tracks)
            }
        }
        player.addListener(listener)
        updateTrackOptions()
        onDispose {
            player.removeListener(listener)
            mediaSession.release()
            player.release()
            activity?.window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }

    LaunchedEffect(player) {
        while (!hasExited) {
            positionMs = player.currentPosition.coerceAtLeast(0)
            player.duration.takeIf { it > 0 && it != C.TIME_UNSET }?.let { durationMs = it }
            delay(500)
        }
    }

    LaunchedEffect(overlayVisible, interactiveOverlay) {
        if (overlayVisible && !interactiveOverlay && errorMessage == null) {
            delay(4_000)
            overlayVisible = false
        }
    }

    LaunchedEffect(player) { playbackFocus.requestFocus() }

    BackHandler {
        if (interactiveOverlay) {
            interactiveOverlay = false
            overlayVisible = true
        } else {
            finish(completed = false)
        }
    }

    Box(
        Modifier
            .fillMaxSize()
            .background(Color.Black)
            .focusRequester(playbackFocus)
            .focusable()
            .onPreviewKeyEvent { event ->
                if (event.nativeKeyEvent.action != KeyEvent.ACTION_DOWN) return@onPreviewKeyEvent false
                when (event.nativeKeyEvent.keyCode) {
                    KeyEvent.KEYCODE_DPAD_LEFT -> {
                        if (interactiveOverlay) {
                            if (selectedControl == 0) cycleAudio() else cycleSubtitles()
                        } else player.seekTo((player.currentPosition - 10_000).coerceAtLeast(0))
                        overlayVisible = true
                        true
                    }
                    KeyEvent.KEYCODE_DPAD_RIGHT -> {
                        if (interactiveOverlay) {
                            if (selectedControl == 0) cycleAudio() else cycleSubtitles()
                        } else {
                            val target = player.currentPosition + 10_000
                            player.seekTo(if (durationMs > 0) target.coerceAtMost(durationMs) else target)
                        }
                        overlayVisible = true
                        true
                    }
                    KeyEvent.KEYCODE_DPAD_CENTER,
                    KeyEvent.KEYCODE_ENTER,
                    KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE -> {
                        if (interactiveOverlay) {
                            if (selectedControl == 0) cycleAudio() else cycleSubtitles()
                        } else if (player.isPlaying) player.pause() else player.play()
                        overlayVisible = true
                        true
                    }
                    KeyEvent.KEYCODE_DPAD_UP -> {
                        if (interactiveOverlay) selectedControl = 0 else interactiveOverlay = true
                        overlayVisible = true
                        true
                    }
                    KeyEvent.KEYCODE_DPAD_DOWN -> {
                        interactiveOverlay = true
                        selectedControl = 1
                        overlayVisible = true
                        true
                    }
                    KeyEvent.KEYCODE_INFO,
                    KeyEvent.KEYCODE_MENU -> {
                        interactiveOverlay = !interactiveOverlay
                        overlayVisible = true
                        true
                    }
                    KeyEvent.KEYCODE_CAPTIONS,
                    KeyEvent.KEYCODE_BUTTON_Y -> {
                        cycleSubtitles()
                        true
                    }
                    KeyEvent.KEYCODE_MEDIA_AUDIO_TRACK,
                    KeyEvent.KEYCODE_BUTTON_X -> {
                        cycleAudio()
                        true
                    }
                    else -> false
                }
            }
    ) {
        AndroidView(
            factory = {
                PlayerView(it).apply {
                    useController = false
                    resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FIT
                    layoutParams = ViewGroup.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.MATCH_PARENT,
                    )
                    this.player = player
                }
            },
            update = { it.player = player },
            modifier = Modifier.fillMaxSize(),
        )

        val logoUrl = session.item.channelLogoUrl
        if (session.item.isLiveChannel && session.item.channelLogoOverlayEnabled == true && !logoUrl.isNullOrBlank()) {
            TaterArtwork(
                item = session.item,
                artworkUrl = logoUrl,
                token = token,
                contentScale = androidx.compose.ui.layout.ContentScale.Fit,
                modifier = Modifier
                    .align(session.item.channelLogoPosition.logoAlignment())
                    .padding(28.dp)
                    .width(154.dp)
                    .height(92.dp),
            )
        }

        if (overlayVisible) {
            PlaybackOverlay(
                title = session.item.title,
                positionMs = positionMs,
                durationMs = durationMs,
                path = listOfNotNull(
                    session.plan.resolutionLabel,
                    "Video ${session.plan.videoMode}",
                    "Audio ${session.plan.audioMode}",
                    session.plan.videoCodec,
                    session.plan.audioCodec,
                ).joinToString("  ·  "),
                audioLabel = audioLabel,
                subtitleLabel = subtitleLabel,
                audioAvailable = maxOf(audioOptions.size, session.plan.source.audioTracks.size) > 1,
                subtitlesAvailable = subtitleOptions.isNotEmpty(),
                interactive = interactiveOverlay,
                selectedControl = selectedControl,
                errorMessage = errorMessage,
                modifier = Modifier.align(Alignment.BottomCenter),
            )
        }
    }
}

@Composable
private fun PlaybackOverlay(
    title: String,
    positionMs: Long,
    durationMs: Long,
    path: String,
    audioLabel: String,
    subtitleLabel: String,
    audioAvailable: Boolean,
    subtitlesAvailable: Boolean,
    interactive: Boolean,
    selectedControl: Int,
    errorMessage: String?,
    modifier: Modifier = Modifier,
) {
    GlassSurface(
        modifier
            .fillMaxWidth()
            .padding(horizontal = 46.dp, vertical = 36.dp),
        cornerRadius = 24.dp,
    ) {
        Column(Modifier.padding(horizontal = 26.dp, vertical = 20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(title, color = Color.White, fontSize = 22.sp)
                Text("${formatTime(positionMs)}  /  ${formatTime(durationMs)}", color = Color.White, fontSize = 17.sp)
            }
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(6.dp)
                    .background(Color.White.copy(alpha = 0.16f), RoundedCornerShape(3.dp))
            ) {
                Box(
                    Modifier
                        .fillMaxWidth(if (durationMs > 0) (positionMs.toFloat() / durationMs).coerceIn(0f, 1f) else 0f)
                        .height(6.dp)
                        .background(TaterColors.Orange, RoundedCornerShape(3.dp))
                )
            }
            if (errorMessage != null) {
                Text(errorMessage, color = Color(0xFFFFB4A7), fontSize = 16.sp)
            } else {
                Row(
                    Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("PLAYBACK PATH", color = TaterColors.OrangeBright, fontSize = 13.sp)
                        Spacer(Modifier.width(14.dp))
                        Text(path, color = TaterColors.SecondaryText, fontSize = 15.sp)
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        TrackPill("AUDIO  $audioLabel", audioAvailable, interactive && selectedControl == 0)
                        TrackPill("CC  $subtitleLabel", subtitlesAvailable, interactive && selectedControl == 1)
                    }
                }
            }
        }
    }
}

@Composable
private fun TrackPill(label: String, available: Boolean, selected: Boolean) {
    Text(
        label,
        color = if (available) Color.White else Color.White.copy(alpha = .38f),
        fontSize = 13.sp,
        fontWeight = androidx.compose.ui.text.font.FontWeight.Bold,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
        modifier = Modifier
            .widthIn(max = 300.dp)
            .background(
                if (selected) TaterColors.Orange.copy(alpha = .28f) else Color.Black.copy(alpha = .62f),
                RoundedCornerShape(14.dp),
            )
            .padding(horizontal = 13.dp, vertical = 8.dp),
    )
}

private data class TrackOption(
    val group: Tracks.Group,
    val trackIndex: Int,
    val label: String,
    val selected: Boolean,
)

private fun List<Tracks.Group>.trackOptions(type: Int): List<TrackOption> = buildList {
    for (group in this@trackOptions) {
        if (group.type != type) continue
        repeat(group.length) { index ->
            if (!group.isTrackSupported(index)) return@repeat
            val format = group.getTrackFormat(index)
            val parts = listOfNotNull(
                format.label?.takeIf { it.isNotBlank() },
                format.language?.takeIf { it.isNotBlank() }?.uppercase(),
                format.codecs?.takeIf { it.isNotBlank() }?.uppercase(),
            ).distinct()
            add(TrackOption(
                group = group,
                trackIndex = index,
                label = parts.joinToString(" · ").ifBlank { if (type == C.TRACK_TYPE_AUDIO) "AUDIO ${size + 1}" else "SUBTITLE ${size + 1}" },
                selected = group.isTrackSelected(index),
            ))
        }
    }
}

private fun com.tatertotterson.tatertubeplayer.model.PlaybackAudioTrack.displayLabel(): String =
    listOfNotNull(
        title?.takeIf { it.isNotBlank() },
        language?.takeIf { it.isNotBlank() }?.uppercase(),
        codec?.takeIf { it.isNotBlank() }?.uppercase(),
        channels?.takeIf { it > 0 }?.let { "$it CH" },
    ).distinct().joinToString(" · ").ifBlank { "AUTO" }

private fun String?.logoAlignment(): Alignment = when (this?.lowercase()) {
    "top-left", "top_left" -> Alignment.TopStart
    "top-right", "top_right" -> Alignment.TopEnd
    "bottom-left", "bottom_left" -> Alignment.BottomStart
    else -> Alignment.BottomEnd
}

private fun formatTime(valueMs: Long): String {
    if (valueMs <= 0 || valueMs == C.TIME_UNSET) return "0:00"
    val totalSeconds = valueMs / 1000
    val hours = totalSeconds / 3600
    val minutes = (totalSeconds % 3600) / 60
    val seconds = totalSeconds % 60
    return if (hours > 0) "%d:%02d:%02d".format(hours, minutes, seconds)
    else "%d:%02d".format(minutes, seconds)
}
