package com.tatertotterson.tatertubeplayer.ui.theme

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.darkColorScheme

object TaterColors {
    val Orange = Color(0xFFFF8617)
    val OrangeBright = Color(0xFFFFA13D)
    val Background = Color.Black
    val Glass = Color(0xD9121212)
    val GlassSoft = Color(0xB20B0B0B)
    val Text = Color(0xFFF7F7F7)
    val SecondaryText = Color(0xFFB9B9B9)
    val Success = Color(0xFF55D67B)
}

private val TaterColorScheme = darkColorScheme(
    primary = TaterColors.Orange,
    onPrimary = Color.Black,
    secondary = TaterColors.OrangeBright,
    background = Color.Black,
    onBackground = TaterColors.Text,
    surface = TaterColors.Glass,
    onSurface = TaterColors.Text,
)

@Composable
fun TaterTubeTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = TaterColorScheme) {
        Box(
            Modifier
                .fillMaxSize()
                .background(TaterColors.Background)
                .drawWithCache {
                    val glow = Brush.radialGradient(
                        colors = listOf(
                            TaterColors.Orange.copy(alpha = 0.19f),
                            TaterColors.Orange.copy(alpha = 0.07f),
                            Color.Transparent,
                        ),
                        center = Offset(size.width * 0.84f, size.height * 0.07f),
                        radius = size.minDimension * 0.82f,
                    )
                    onDrawBehind { drawRect(glow) }
                }
        ) {
            content()
        }
    }
}

fun Modifier.taterFocusGlow(
    focused: Boolean,
    shape: Shape,
    elevation: Dp = 18.dp,
): Modifier = if (focused) {
    shadow(
        elevation = elevation,
        shape = shape,
        clip = false,
        ambientColor = TaterColors.Orange.copy(alpha = 0.42f),
        spotColor = TaterColors.Orange.copy(alpha = 0.58f),
    )
} else {
    this
}
