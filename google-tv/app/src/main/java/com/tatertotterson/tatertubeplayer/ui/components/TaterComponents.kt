package com.tatertotterson.tatertubeplayer.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.tv.material3.Text
import coil3.annotation.ExperimentalCoilApi
import coil3.compose.AsyncImage
import coil3.network.NetworkHeaders
import coil3.network.httpHeaders
import coil3.request.ImageRequest
import com.tatertotterson.tatertubeplayer.R
import com.tatertotterson.tatertubeplayer.model.MediaItem
import com.tatertotterson.tatertubeplayer.ui.theme.TaterColors
import com.tatertotterson.tatertubeplayer.ui.theme.taterFocusGlow
import kotlinx.coroutines.delay

private val GlassShape = RoundedCornerShape(22.dp)

@Composable
fun RestoreInitialFocus(
    requester: FocusRequester,
    focusKey: Any?,
    enabled: Boolean,
) {
    LaunchedEffect(focusKey, enabled) {
        if (!enabled) return@LaunchedEffect
        delay(120)
        runCatching { requester.requestFocus() }
    }
}

@Composable
fun GlassSurface(
    modifier: Modifier = Modifier,
    cornerRadius: Dp = 22.dp,
    content: @Composable () -> Unit,
) {
    val shape = RoundedCornerShape(cornerRadius)
    Box(
        modifier
            .clip(shape)
            .background(TaterColors.Glass)
            .border(1.dp, Color.White.copy(alpha = 0.12f), shape)
    ) {
        content()
    }
}

@Composable
fun TaterButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    var focused by remember { mutableStateOf(false) }
    val borderColor by animateColorAsState(
        if (focused) TaterColors.OrangeBright else Color.White.copy(alpha = 0.10f),
        label = "button-border",
    )
    val scale by animateFloatAsState(if (focused) 1.035f else 1f, label = "button-scale")
    val shape = RoundedCornerShape(18.dp)
    Box(
        modifier
            .onFocusChanged { focused = it.isFocused }
            .clickable(enabled = enabled, onClick = onClick)
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
            }
            .taterFocusGlow(focused, shape, 15.dp)
            .border(if (focused) 3.dp else 1.dp, borderColor, shape)
            .background(Color.Black.copy(alpha = if (enabled) 0.88f else 0.45f), shape)
            .padding(horizontal = 25.dp, vertical = 14.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = text,
            color = if (enabled) Color.White else TaterColors.SecondaryText,
            fontSize = 18.sp,
            fontWeight = FontWeight.Bold,
            maxLines = 1,
        )
    }
}

@OptIn(ExperimentalCoilApi::class)
@Composable
fun TaterArtwork(
    item: MediaItem,
    artworkUrl: String?,
    token: String?,
    modifier: Modifier = Modifier,
    contentScale: ContentScale = ContentScale.Crop,
    backgroundColor: Color = Color(0xFF171717),
) {
    if (item.artworkResource != null) {
        Image(
            painter = painterResource(item.artworkResource),
            contentDescription = item.title,
            contentScale = contentScale,
            modifier = modifier,
        )
        return
    }

    val context = LocalContext.current
    val model = remember(artworkUrl, token) {
        artworkUrl?.let { url ->
            ImageRequest.Builder(context)
                .data(url)
                .apply {
                    if (!token.isNullOrBlank()) {
                        httpHeaders(
                            NetworkHeaders.Builder()
                                .set("Authorization", "Bearer $token")
                                .build()
                        )
                    }
                }
                .build()
        }
    }
    AsyncImage(
        model = model,
        contentDescription = item.title,
        contentScale = contentScale,
        modifier = modifier.background(backgroundColor),
        error = painterResource(R.drawable.tater_launcher_icon),
        fallback = painterResource(R.drawable.tater_launcher_icon),
    )
}

@Composable
fun MediaCard(
    item: MediaItem,
    artworkUrl: String?,
    token: String?,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var focused by remember { mutableStateOf(false) }
    val borderColor by animateColorAsState(
        if (focused) TaterColors.OrangeBright else Color.Transparent,
        label = "card-border",
    )
    val scale by animateFloatAsState(if (focused) 1.045f else 1f, label = "card-scale")
    Box(
        modifier = modifier
            .width(340.dp)
            .height(202.dp)
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
            }
            .onFocusChanged { focused = it.isFocused }
            .clickable(onClick = onClick)
            .taterFocusGlow(focused, GlassShape)
            .clip(GlassShape)
            .border(if (focused) 4.dp else 1.dp, borderColor, GlassShape),
    ) {
        TaterArtwork(
            item = item,
            artworkUrl = artworkUrl,
            token = token,
            modifier = Modifier.fillMaxSize(),
        )
        Box(
            Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        listOf(Color.Black.copy(alpha = .08f), Color.Black.copy(alpha = .38f), Color.Black.copy(alpha = .92f))
                    )
                )
        )
        Column(
            Modifier.align(Alignment.BottomStart).padding(horizontal = 20.dp, vertical = if (item.progressPercent > .5) 19.dp else 17.dp),
            verticalArrangement = Arrangement.spacedBy(5.dp),
        ) {
            Text(
                text = if (item.isLiveChannel) {
                    if (item.channelNumber.isNullOrBlank()) "LIVE" else "CH ${item.channelNumber}  •  LIVE"
                } else {
                    listOfNotNull((item.mediaType ?: item.type ?: "VIDEO").uppercase(), item.date).joinToString("  •  ")
                },
                color = TaterColors.OrangeBright,
                fontSize = 15.sp,
                fontWeight = FontWeight.Black,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(item.title, color = Color.White, fontSize = 25.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
            val subtitle = when {
                item.recentItems.size == 1 -> item.recentItems.first().title
                item.recentItems.size > 1 -> "${item.recentItems.size} recently added episodes"
                else -> item.subtitle ?: item.category
            }
            subtitle?.takeIf(String::isNotBlank)?.let {
                Text(it, color = Color.White.copy(alpha = .72f), fontSize = 17.sp, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
        if (item.progressPercent > 0.5 || item.viewOffsetMs > 0) {
            Box(Modifier.align(Alignment.BottomStart).fillMaxWidth().height(6.dp).background(Color.White.copy(alpha = .24f))) {
                Box(
                    Modifier
                        .fillMaxWidth(if (item.progressPercent > .5) (item.progressPercent / 100.0).toFloat().coerceIn(0f, 1f) else .10f)
                        .height(6.dp)
                        .background(TaterColors.Orange)
                )
            }
        }
    }
}

@Composable
fun SectionHeading(title: String, detail: String? = null) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.Bottom,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(title, color = Color.White, fontSize = 34.sp, fontWeight = FontWeight.Bold)
        if (detail != null) {
            Text(detail, color = TaterColors.OrangeBright, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
        }
    }
    Spacer(Modifier.height(22.dp))
}
