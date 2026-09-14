package com.tatertotterson.tatertubeplayer

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import com.tatertotterson.tatertubeplayer.ui.PlayerViewModel
import com.tatertotterson.tatertubeplayer.ui.TaterTubeApp
import com.tatertotterson.tatertubeplayer.ui.theme.TaterTubeTheme

class MainActivity : ComponentActivity() {
    private val playerViewModel: PlayerViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        WindowCompat.getInsetsController(window, window.decorView).hide(WindowInsetsCompat.Type.systemBars())

        setContent {
            TaterTubeTheme {
                TaterTubeApp(playerViewModel)
            }
        }
        playerViewModel.handleDeepLink(intent?.data)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        playerViewModel.handleDeepLink(intent.data)
    }
}
