package com.tatertotterson.tatertubeplayer.ui.theme

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
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
                .background(
                    Brush.radialGradient(
                        colors = listOf(TaterColors.Orange.copy(alpha = 0.17f), Color.Transparent),
                        center = Offset(1500f, 40f),
                        radius = 1050f,
                    )
                )
                .background(TaterColors.Background.copy(alpha = 0.82f))
        ) {
            content()
        }
    }
}
