package com.tatertotterson.tatertubeplayer.ui

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.tatertotterson.tatertubeplayer.data.CredentialStore
import com.tatertotterson.tatertubeplayer.data.DemoCatalog
import com.tatertotterson.tatertubeplayer.data.DeviceCapabilities
import com.tatertotterson.tatertubeplayer.data.PlaybackCapabilities
import com.tatertotterson.tatertubeplayer.data.SavedConnection
import com.tatertotterson.tatertubeplayer.data.TaterApiClient
import com.tatertotterson.tatertubeplayer.model.MediaItem
import com.tatertotterson.tatertubeplayer.model.ModelParser
import com.tatertotterson.tatertubeplayer.model.PlaybackPlan
import com.tatertotterson.tatertubeplayer.model.PlayerHome
import kotlinx.coroutines.launch
import java.io.File

enum class AppPhase { STARTING, PAIRING, READY }

enum class Destination(val label: String, val glyph: String) {
    HOME("Home", "⌂"),
    LIBRARY("Library", "▤"),
    LIVE_TV("Live TV", "▣"),
    DISCOVER("Discover", "✦"),
    TATER_PICKS("Tater Picks", "✧"),
    SETTINGS("Settings", "⚙"),
}

data class PlaybackSession(
    val item: MediaItem,
    val plan: PlaybackPlan,
    val startPositionMs: Long,
)

data class PlayerUiState(
    val phase: AppPhase = AppPhase.STARTING,
    val home: PlayerHome? = null,
    val destination: Destination = Destination.HOME,
    val menuVisible: Boolean = false,
    val selectedMedia: MediaItem? = null,
    val playback: PlaybackSession? = null,
    val isRefreshing: Boolean = false,
    val isPreparingPlayback: Boolean = false,
    val isDemo: Boolean = false,
    val errorMessage: String? = null,
)

class PlayerViewModel(application: Application) : AndroidViewModel(application) {
    private val credentials = CredentialStore(application)
    private val homeCache = File(application.cacheDir, "google-tv/home.json")
    private var connection: SavedConnection? = null
    private var client: TaterApiClient? = null
    private var capabilities: PlaybackCapabilities = DeviceCapabilities.read(application)

    var state by mutableStateOf(PlayerUiState())
        private set

    val token: String?
        get() = connection?.token

    init {
        viewModelScope.launch { start() }
    }

    fun pair(serverAddress: String, pin: String) {
        if (pin.trim().length < 4) {
            state = state.copy(errorMessage = "Enter the pairing code shown by Tater Tube Server.")
            return
        }
        viewModelScope.launch {
            state = state.copy(isRefreshing = true, errorMessage = null)
            runCatching {
                val serverUrl = TaterApiClient.normalizeServerUrl(serverAddress)
                val pairingClient = TaterApiClient(serverUrl)
                val result = pairingClient.pair(pin.trim())
                SavedConnection(serverUrl, result.token, result.playerName).also(credentials::save)
            }.onSuccess { saved ->
                connect(saved)
                state = state.copy(phase = AppPhase.READY, isDemo = false, isRefreshing = false)
                refreshHome(showError = true)
                reportCapabilities()
            }.onFailure { error ->
                state = state.copy(isRefreshing = false, errorMessage = error.userMessage())
            }
        }
    }

    fun enterDemo() {
        connection = null
        client = null
        state = PlayerUiState(
            phase = AppPhase.READY,
            home = DemoCatalog.home,
            isDemo = true,
        )
    }

    fun refreshHome(showError: Boolean = false) {
        val api = client ?: return
        if (state.isRefreshing) return
        viewModelScope.launch {
            state = state.copy(isRefreshing = true)
            runCatching { api.home() }
                .onSuccess { (raw, home) ->
                    homeCache.parentFile?.mkdirs()
                    homeCache.writeText(raw)
                    state = state.copy(home = home, isRefreshing = false, errorMessage = null)
                }
                .onFailure { error ->
                    state = state.copy(
                        isRefreshing = false,
                        errorMessage = if (showError || state.home == null) error.userMessage() else null,
                    )
                }
        }
    }

    fun selectDestination(destination: Destination) {
        state = state.copy(destination = destination, menuVisible = false, selectedMedia = null)
    }

    fun showMenu() {
        if (state.playback == null && state.selectedMedia == null) state = state.copy(menuVisible = true)
    }

    fun hideMenu() {
        state = state.copy(menuVisible = false)
    }

    fun openDetails(item: MediaItem) {
        state = state.copy(selectedMedia = item, menuVisible = false)
    }

    fun closeDetails() {
        state = state.copy(selectedMedia = null)
    }

    fun play(item: MediaItem, resume: Boolean) {
        val api = client
        if (state.isDemo || api == null) {
            state = state.copy(errorMessage = "Pair with your Tater Tube Server to play this title.")
            return
        }
        if (state.isPreparingPlayback) return
        viewModelScope.launch {
            state = state.copy(isPreparingPlayback = true, errorMessage = null)
            runCatching { api.playbackPlan(item, capabilities) }
                .onSuccess { plan ->
                    state = state.copy(
                        isPreparingPlayback = false,
                        selectedMedia = null,
                        playback = PlaybackSession(
                            item = item,
                            plan = plan,
                            startPositionMs = if (resume) item.viewOffsetMs else 0,
                        ),
                    )
                    runCatching {
                        api.savePlayState(item, state.playback?.startPositionMs ?: 0, item.durationMs, false, true)
                    }
                }
                .onFailure { error ->
                    state = state.copy(isPreparingPlayback = false, errorMessage = error.userMessage())
                }
        }
    }

    fun stopPlayback(positionMs: Long, durationMs: Long, completed: Boolean) {
        val session = state.playback ?: return
        state = state.copy(playback = null)
        updateVisibleProgress(session.item, positionMs, durationMs, completed)
        client?.let { api ->
            viewModelScope.launch {
                runCatching {
                    api.savePlayState(session.item, positionMs, durationMs, completed, false)
                }
                refreshHome(showError = false)
            }
        }
    }

    fun dismissError() {
        state = state.copy(errorMessage = null)
    }

    fun disconnect() {
        credentials.clear()
        connection = null
        client = null
        state = PlayerUiState(phase = AppPhase.PAIRING)
    }

    fun artworkUrl(item: MediaItem): String? = item.preferredArtwork?.let { value ->
        client?.resolveUrl(value) ?: value
    }

    private suspend fun start() {
        val saved = credentials.load()
        if (saved == null) {
            state = state.copy(phase = AppPhase.PAIRING)
            return
        }
        connect(saved)
        val cached = runCatching { ModelParser.home(homeCache.readText()) }.getOrNull()
        state = state.copy(phase = AppPhase.READY, home = cached)
        refreshHome(showError = cached == null)
        reportCapabilities()
    }

    private fun connect(saved: SavedConnection) {
        connection = saved
        client = TaterApiClient(saved.serverUrl, saved.token)
        capabilities = DeviceCapabilities.read(getApplication())
    }

    private fun reportCapabilities() {
        val api = client ?: return
        viewModelScope.launch {
            capabilities = DeviceCapabilities.read(getApplication())
            runCatching { api.reportCapabilities(capabilities) }
        }
    }

    private fun updateVisibleProgress(item: MediaItem, positionMs: Long, durationMs: Long, completed: Boolean) {
        val home = state.home ?: return
        val percent = if (completed || durationMs <= 0) 0.0 else positionMs.toDouble() / durationMs * 100.0
        fun update(list: List<MediaItem>) = list.map {
            if (it.id == item.id || (!it.playStateId.isNullOrBlank() && it.playStateId == item.playStateId)) {
                it.copy(
                    progressPercent = percent.coerceIn(0.0, 100.0),
                    viewOffsetMs = if (completed) 0 else positionMs,
                    durationMs = durationMs,
                )
            } else it
        }.filterNot { completed && (it.id == item.id || it.playStateId == item.playStateId) }
        state = state.copy(
            home = home.copy(
                continueWatching = update(home.continueWatching),
                recentlyAdded = update(home.recentlyAdded),
            )
        )
    }

    private fun Throwable.userMessage(): String = message?.takeIf { it.isNotBlank() }
        ?: "Tater Tube Player could not complete that request."
}
