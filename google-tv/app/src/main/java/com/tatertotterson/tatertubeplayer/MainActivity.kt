package com.tatertotterson.tatertubeplayer

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.lifecycle.viewmodel.compose.viewModel
import com.tatertotterson.tatertubeplayer.ui.PlayerViewModel
import com.tatertotterson.tatertubeplayer.ui.TaterTubeApp
import com.tatertotterson.tatertubeplayer.ui.theme.TaterTubeTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        WindowCompat.getInsetsController(window, window.decorView).hide(WindowInsetsCompat.Type.systemBars())

        setContent {
            TaterTubeTheme {
                val playerViewModel: PlayerViewModel = viewModel()
                TaterTubeApp(playerViewModel)
            }
        }
    }
}
