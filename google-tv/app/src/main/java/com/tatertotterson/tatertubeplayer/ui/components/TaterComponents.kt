package com.tatertotterson.tatertubeplayer.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
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

private val GlassShape = RoundedCornerShape(22.dp)

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
            .focusable(enabled)
            .clickable(enabled = enabled, onClick = onClick)
            .border(if (focused) 3.dp else 1.dp, borderColor, shape)
            .background(Color.Black.copy(alpha = if (enabled) 0.88f else 0.45f), shape)
            .padding(horizontal = 25.dp, vertical = 14.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = text,
            color = if (enabled) Color.White else TaterColors.SecondaryText,
            fontSize = 18.sp * scale,
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
        modifier = modifier.background(Color(0xFF171717)),
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
    Column(
        modifier = modifier
            .width(248.dp * scale)
            .onFocusChanged { focused = it.isFocused }
            .focusable()
            .clickable(onClick = onClick),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Box(
            Modifier
                .fillMaxWidth()
                .height(146.dp * scale)
                .clip(GlassShape)
                .border(if (focused) 4.dp else 1.dp, borderColor, GlassShape)
        ) {
            TaterArtwork(
                item = item,
                artworkUrl = artworkUrl,
                token = token,
                modifier = Modifier.fillMaxSize(),
            )
            if (item.progressPercent > 0.5) {
                Box(
                    Modifier
                        .align(Alignment.BottomStart)
                        .fillMaxWidth()
                        .height(5.dp)
                        .background(Color.Black.copy(alpha = 0.72f))
                ) {
                    Box(
                        Modifier
                            .fillMaxWidth((item.progressPercent / 100.0).toFloat().coerceIn(0f, 1f))
                            .height(5.dp)
                            .background(TaterColors.Orange)
                    )
                }
            }
        }
        Text(
            text = item.title,
            color = Color.White,
            fontSize = 17.sp,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(horizontal = 3.dp),
        )
        item.subtitle?.let {
            Text(
                text = it,
                color = TaterColors.SecondaryText,
                fontSize = 14.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(horizontal = 3.dp),
            )
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
        Text(title, color = Color.White, fontSize = 25.sp, fontWeight = FontWeight.Bold)
        if (detail != null) {
            Text(detail, color = TaterColors.OrangeBright, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
        }
    }
    Spacer(Modifier.height(14.dp))
}
