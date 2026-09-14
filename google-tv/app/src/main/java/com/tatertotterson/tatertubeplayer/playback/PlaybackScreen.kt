package com.tatertotterson.tatertubeplayer.playback

import android.app.Activity
import android.view.KeyEvent
import android.view.ViewGroup
import android.view.WindowManager
import androidx.activity.compose.BackHandler
import androidx.annotation.OptIn
import androidx.compose.foundation.background
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
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
import com.tatertotterson.tatertubeplayer.ui.theme.TaterColors
import kotlinx.coroutines.delay

@OptIn(UnstableApi::class)
@Composable
fun PlaybackScreen(
    session: PlaybackSession,
    token: String?,
    onExit: (positionMs: Long, durationMs: Long, completed: Boolean) -> Unit,
) {
    val context = LocalContext.current
    val activity = context as? Activity
    var positionMs by remember(session.item.id) { mutableLongStateOf(session.startPositionMs) }
    var durationMs by remember(session.item.id) { mutableLongStateOf(session.item.durationMs) }
    var overlayVisible by remember(session.item.id) { mutableStateOf(true) }
    var errorMessage by remember(session.item.id) { mutableStateOf<String?>(null) }
    var hasExited by remember(session.item.id) { mutableStateOf(false) }

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
        }
        player.addListener(listener)
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

    LaunchedEffect(overlayVisible) {
        if (overlayVisible && errorMessage == null) {
            delay(4_000)
            overlayVisible = false
        }
    }

    BackHandler { finish(completed = false) }

    Box(
        Modifier
            .fillMaxSize()
            .background(Color.Black)
            .onPreviewKeyEvent { event ->
                if (event.nativeKeyEvent.action != KeyEvent.ACTION_DOWN) return@onPreviewKeyEvent false
                when (event.nativeKeyEvent.keyCode) {
                    KeyEvent.KEYCODE_DPAD_LEFT -> {
                        player.seekTo((player.currentPosition - 10_000).coerceAtLeast(0))
                        overlayVisible = true
                        true
                    }
                    KeyEvent.KEYCODE_DPAD_RIGHT -> {
                        val target = player.currentPosition + 10_000
                        player.seekTo(if (durationMs > 0) target.coerceAtMost(durationMs) else target)
                        overlayVisible = true
                        true
                    }
                    KeyEvent.KEYCODE_DPAD_CENTER,
                    KeyEvent.KEYCODE_ENTER,
                    KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE -> {
                        if (player.isPlaying) player.pause() else player.play()
                        overlayVisible = true
                        true
                    }
                    KeyEvent.KEYCODE_DPAD_UP,
                    KeyEvent.KEYCODE_INFO,
                    KeyEvent.KEYCODE_MENU -> {
                        overlayVisible = !overlayVisible
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
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("PLAYBACK PATH", color = TaterColors.OrangeBright, fontSize = 13.sp)
                    Spacer(Modifier.width(14.dp))
                    Text(path, color = TaterColors.SecondaryText, fontSize = 15.sp)
                }
            }
        }
    }
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
