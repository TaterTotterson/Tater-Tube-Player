package com.tatertotterson.tatertubeplayer.ui

import android.app.Application
import android.media.MediaPlayer
import android.net.Uri
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.tatertotterson.tatertubeplayer.R
import com.tatertotterson.tatertubeplayer.data.CredentialStore
import com.tatertotterson.tatertubeplayer.data.DemoCatalog
import com.tatertotterson.tatertubeplayer.data.DeviceCapabilities
import com.tatertotterson.tatertubeplayer.data.PlaybackCapabilities
import com.tatertotterson.tatertubeplayer.data.SavedConnection
import com.tatertotterson.tatertubeplayer.data.TaterApiClient
import com.tatertotterson.tatertubeplayer.data.WatchNextPublisher
import com.tatertotterson.tatertubeplayer.model.DiscoverCategory
import com.tatertotterson.tatertubeplayer.model.DiscoverPreparedFile
import com.tatertotterson.tatertubeplayer.model.LibraryLocation
import com.tatertotterson.tatertubeplayer.model.LibraryPage
import com.tatertotterson.tatertubeplayer.model.LibraryRow
import com.tatertotterson.tatertubeplayer.model.LiveChannel
import com.tatertotterson.tatertubeplayer.model.LiveGuide
import com.tatertotterson.tatertubeplayer.model.LiveProgram
import com.tatertotterson.tatertubeplayer.model.MediaItem
import com.tatertotterson.tatertubeplayer.model.ModelParser
import com.tatertotterson.tatertubeplayer.model.PlaybackPlan
import com.tatertotterson.tatertubeplayer.model.PlayerHome
import com.tatertotterson.tatertubeplayer.model.RecommendationBatch
import com.tatertotterson.tatertubeplayer.model.RecommendationItem
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.io.File
import java.security.MessageDigest
import java.util.UUID

enum class AppPhase { STARTING, PAIRING, READY }

enum class Destination(val label: String, val glyph: String) {
    HOME("Home", "⌂"),
    LIBRARY("Library", "▤"),
    LIVE_TV("Live TV", "▣"),
    DISCOVER("Discover", "✦"),
    TATER_PICKS("Tater Picks", "✧"),
    SETTINGS("Settings", "⚙"),
}

enum class DiscoverStage { CATEGORIES, TITLES, RESULTS, FILES }

sealed interface TaterSpeechState {
    data object Idle : TaterSpeechState
    data object Loading : TaterSpeechState
    data object Speaking : TaterSpeechState
    data class Failed(val message: String) : TaterSpeechState
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
    val libraryRows: List<LibraryRow> = emptyList(),
    val libraryStack: List<LibraryLocation> = emptyList(),
    val libraryPages: Map<String, LibraryPage> = emptyMap(),
    val loadingLibraryKey: String? = null,
    val isLibraryRefreshing: Boolean = false,
    val liveGuide: LiveGuide? = null,
    val isLiveGuideRefreshing: Boolean = false,
    val discoverCategories: List<DiscoverCategory> = emptyList(),
    val discoverStage: DiscoverStage = DiscoverStage.CATEGORIES,
    val discoverCategory: DiscoverCategory? = null,
    val discoverTitle: MediaItem? = null,
    val discoverPage: LibraryPage? = null,
    val preparedFiles: List<DiscoverPreparedFile> = emptyList(),
    val isDiscoverRefreshing: Boolean = false,
    val isPreparingDiscovery: Boolean = false,
    val recommendationBatch: RecommendationBatch? = null,
    val recommendations: List<RecommendationItem> = emptyList(),
    val isRecommendationsRefreshing: Boolean = false,
    val speechState: TaterSpeechState = TaterSpeechState.Idle,
)

class PlayerViewModel(application: Application) : AndroidViewModel(application) {
    private val credentials = CredentialStore(application)
    private val cacheRoot = File(application.cacheDir, "google-tv").apply { mkdirs() }
    private val homeCache = File(cacheRoot, "home.json")
    private val libraryRowsCache = File(cacheRoot, "library-rows.json")
    private val guideCache = File(cacheRoot, "live-guide.json")
    private val discoverCatalogCache = File(cacheRoot, "discover-catalog.json")
    private val recommendationsCache = File(cacheRoot, "recommendations.json")
    private val libraryShuffleSeed = UUID.randomUUID().toString()
    private var connection: SavedConnection? = null
    private var client: TaterApiClient? = null
    private var capabilities: PlaybackCapabilities = DeviceCapabilities.read(application)
    private var speechJob: Job? = null
    private var speechPlayer: MediaPlayer? = null
    private var speechRequestId: String? = null
    private var spokenBatchId: String? = null
    private var pendingDeepLinkId: String? = null
    private var discoverPageJob: Job? = null

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
                val result = TaterApiClient(serverUrl).pair(pin.trim())
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
        stopRecommendationSpeech()
        connection = null
        client = null
        state = PlayerUiState(
            phase = AppPhase.READY,
            home = DemoCatalog.home,
            libraryRows = DemoCatalog.libraryRows,
            liveGuide = DemoCatalog.liveGuide,
            discoverCategories = DemoCatalog.discoveryCategories,
            recommendationBatch = DemoCatalog.recommendations.batch,
            recommendations = DemoCatalog.recommendations.items,
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
                    homeCache.writeText(raw)
                    state = state.copy(home = home, isRefreshing = false, errorMessage = null)
                    viewModelScope.launch { WatchNextPublisher.publish(getApplication(), home.continueWatching) }
                    openPendingDeepLink()
                    if (home.capabilities.tubeTV) refreshLiveGuide()
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
        if (state.destination == Destination.TATER_PICKS && destination != Destination.TATER_PICKS) {
            stopRecommendationSpeech()
        }
        state = state.copy(
            destination = destination,
            menuVisible = false,
            selectedMedia = null,
            libraryStack = if (destination == Destination.LIBRARY) state.libraryStack else emptyList(),
        )
        when (destination) {
            Destination.LIBRARY -> refreshLibraryRows()
            Destination.LIVE_TV -> refreshLiveGuide()
            Destination.DISCOVER -> refreshDiscoverCatalog()
            Destination.TATER_PICKS -> refreshRecommendations()
            else -> Unit
        }
    }

    fun handleBack() {
        when {
            state.selectedMedia != null -> closeDetails()
            state.menuVisible -> hideMenu()
            state.destination == Destination.LIBRARY && state.libraryStack.isNotEmpty() ->
                state = state.copy(libraryStack = state.libraryStack.dropLast(1))
            state.destination == Destination.DISCOVER && state.discoverStage != DiscoverStage.CATEGORIES -> {
                when (state.discoverStage) {
                    DiscoverStage.FILES -> state = state.copy(
                        discoverStage = DiscoverStage.RESULTS,
                        preparedFiles = emptyList(),
                    )
                    DiscoverStage.RESULTS -> {
                        val category = state.discoverCategory
                        if (category != null) openDiscoverCategory(category)
                        else state = state.copy(
                            discoverStage = DiscoverStage.CATEGORIES,
                            discoverTitle = null,
                            discoverPage = null,
                        )
                    }
                    DiscoverStage.TITLES -> {
                        discoverPageJob?.cancel()
                        discoverPageJob = null
                        state = state.copy(
                            discoverStage = DiscoverStage.CATEGORIES,
                            discoverCategory = null,
                            discoverPage = null,
                            isDiscoverRefreshing = false,
                        )
                    }
                    DiscoverStage.CATEGORIES -> Unit
                }
            }
            state.destination != Destination.HOME -> selectDestination(Destination.HOME)
            else -> showMenu()
        }
    }

    fun showMenu() {
        if (state.playback == null && state.selectedMedia == null) state = state.copy(menuVisible = true)
    }

    fun handleDeepLink(uri: Uri?) {
        if (uri?.scheme != "tatertubeplayer" || uri.host != "continue") return
        pendingDeepLinkId = uri.getQueryParameter("id")?.takeIf { it.isNotBlank() }
        openPendingDeepLink()
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

    fun refreshLibraryRows() {
        if (state.isDemo || state.isLibraryRefreshing) return
        val api = client ?: return
        viewModelScope.launch {
            state = state.copy(isLibraryRefreshing = true)
            runCatching { api.libraryRows(libraryShuffleSeed) }
                .onSuccess { (raw, rows) ->
                    libraryRowsCache.writeText(raw)
                    state = state.copy(libraryRows = rows, isLibraryRefreshing = false)
                }
                .onFailure { error ->
                    state = state.copy(
                        isLibraryRefreshing = false,
                        errorMessage = if (state.libraryRows.isEmpty()) error.userMessage() else state.errorMessage,
                    )
                }
        }
    }

    fun openLibrary(location: LibraryLocation) {
        state = state.copy(libraryStack = state.libraryStack + location)
        loadLibraryPage(location)
    }

    fun activateLibraryItem(item: MediaItem, parent: LibraryLocation, recentlyAdded: Boolean = false) {
        if (recentlyAdded && item.recentItems.size == 1) {
            openDetails(item.recentItems.first())
            return
        }
        if (item.isBrowsable) {
            openLibrary(recentlyAddedLocation(item) ?: LibraryLocation.fromItem(item, parent))
        } else {
            openDetails(item)
        }
    }

    fun loadLibraryPage(location: LibraryLocation, force: Boolean = false) {
        val key = location.cacheKey
        if (state.isDemo) {
            state = state.copy(libraryPages = state.libraryPages + (key to DemoCatalog.libraryPage(location)))
            return
        }
        if (!force && state.libraryPages.containsKey(key)) return
        val api = client ?: return
        if (state.loadingLibraryKey == key) return
        val cached = readCache(cacheFile("library", key), ModelParser::libraryPage)
        if (cached != null && !state.libraryPages.containsKey(key)) {
            state = state.copy(libraryPages = state.libraryPages + (key to cached))
        }
        viewModelScope.launch {
            state = state.copy(loadingLibraryKey = key)
            runCatching { api.libraryPage(location, libraryShuffleSeed) }
                .onSuccess { (raw, page) ->
                    cacheFile("library", key).writeText(raw)
                    state = state.copy(
                        libraryPages = state.libraryPages + (key to page),
                        loadingLibraryKey = null,
                    )
                }
                .onFailure { error ->
                    state = state.copy(
                        loadingLibraryKey = null,
                        errorMessage = if (!state.libraryPages.containsKey(key)) error.userMessage() else state.errorMessage,
                    )
                }
        }
    }

    fun refreshLiveGuide() {
        if (state.isDemo || state.isLiveGuideRefreshing) return
        val api = client ?: return
        viewModelScope.launch {
            state = state.copy(isLiveGuideRefreshing = true)
            runCatching { api.liveGuide() }
                .onSuccess { (raw, guide) ->
                    guideCache.writeText(raw)
                    state = state.copy(liveGuide = guide, isLiveGuideRefreshing = false)
                }
                .onFailure { error ->
                    state = state.copy(
                        isLiveGuideRefreshing = false,
                        errorMessage = if (state.liveGuide == null) error.userMessage() else state.errorMessage,
                    )
                }
        }
    }

    fun playChannel(channel: LiveChannel) = play(channel.playbackItem(), resume = false)

    fun refreshDiscoverCatalog() {
        if (state.isDemo || state.isDiscoverRefreshing) return
        val api = client ?: return
        viewModelScope.launch {
            state = state.copy(isDiscoverRefreshing = true)
            runCatching { api.discoverCatalog() }
                .onSuccess { (raw, categories) ->
                    discoverCatalogCache.writeText(raw)
                    state = state.copy(discoverCategories = categories, isDiscoverRefreshing = false)
                }
                .onFailure { error ->
                    if (error is CancellationException) return@onFailure
                    state = state.copy(
                        isDiscoverRefreshing = false,
                        errorMessage = if (state.discoverCategories.isEmpty()) error.userMessage() else state.errorMessage,
                    )
                }
        }
    }

    fun openDiscoverCategory(category: DiscoverCategory) {
        state = state.copy(
            discoverStage = DiscoverStage.TITLES,
            discoverCategory = category,
            discoverTitle = null,
            discoverPage = null,
        )
        if (state.isDemo) {
            state = state.copy(discoverPage = DemoCatalog.discoveryPage(category))
            return
        }
        val api = client ?: return
        val key = "feed|${category.id.lowercase()}"
        loadDiscoverPage(key) { api.discoverFeed(category) }
    }

    fun openDiscoverTitle(item: MediaItem) {
        state = state.copy(
            discoverStage = DiscoverStage.RESULTS,
            discoverTitle = item,
            discoverPage = null,
            preparedFiles = emptyList(),
        )
        if (state.isDemo) {
            state = state.copy(discoverPage = DemoCatalog.discoverySearchResults(item))
            return
        }
        val api = client ?: return
        val key = "search|${item.mediaType.orEmpty().lowercase()}|${(item.searchQuery ?: item.title).lowercase()}"
        loadDiscoverPage(key) { api.discoverSearch(item) }
    }

    private fun loadDiscoverPage(key: String, loader: suspend () -> Pair<String, LibraryPage>) {
        discoverPageJob?.cancel()
        val cached = readCache(cacheFile("discover", key), ModelParser::libraryPage)
        if (cached != null) state = state.copy(discoverPage = cached)
        discoverPageJob = viewModelScope.launch {
            state = state.copy(isDiscoverRefreshing = true)
            runCatching { loader() }
                .onSuccess { (raw, page) ->
                    cacheFile("discover", key).writeText(raw)
                    state = state.copy(discoverPage = page, isDiscoverRefreshing = false)
                }
                .onFailure { error ->
                    state = state.copy(
                        isDiscoverRefreshing = false,
                        errorMessage = if (state.discoverPage == null) error.userMessage() else state.errorMessage,
                    )
                }
        }
    }

    fun prepareDiscoverRelease(release: MediaItem) {
        val source = state.discoverTitle ?: return
        if (state.isDemo) {
            startPlayback(
                release.copy(
                    title = source.title,
                    subtitle = source.subtitle,
                    summary = source.summary,
                    mediaType = source.mediaType,
                    nzbUrl = null,
                    artworkResource = source.artworkResource,
                ),
                resume = false,
                holdDiscoveryOverlay = true,
            )
            return
        }
        val api = client ?: run {
            state = state.copy(errorMessage = "Pair with your Tater Tube Server to prepare this stream.")
            return
        }
        if (state.isPreparingDiscovery) return
        viewModelScope.launch {
            state = state.copy(isPreparingDiscovery = true)
            runCatching { api.prepareDiscovery(release, source) }
                .onSuccess { files ->
                    when {
                        files.isEmpty() -> state = state.copy(
                            isPreparingDiscovery = false,
                            errorMessage = "The server did not return a playable file.",
                        )
                        files.size == 1 -> {
                            startPlayback(
                                files.first().playbackItem,
                                resume = false,
                                holdDiscoveryOverlay = true,
                            )
                        }
                        else -> state = state.copy(
                            isPreparingDiscovery = false,
                            discoverStage = DiscoverStage.FILES,
                            preparedFiles = files,
                        )
                    }
                }
                .onFailure { error -> state = state.copy(isPreparingDiscovery = false, errorMessage = error.userMessage()) }
        }
    }

    fun playPreparedFile(file: DiscoverPreparedFile) {
        if (state.isPreparingDiscovery || state.isPreparingPlayback) return
        state = state.copy(isPreparingDiscovery = true)
        startPlayback(file.playbackItem, resume = false, holdDiscoveryOverlay = true)
    }

    fun finishDiscoveryPreparation() {
        if (state.isPreparingDiscovery) state = state.copy(isPreparingDiscovery = false)
    }

    fun refreshRecommendations() {
        if (state.isDemo) {
            beginRecommendationSpeechIfNeeded()
            return
        }
        if (state.isRecommendationsRefreshing) return
        val api = client ?: return
        viewModelScope.launch {
            state = state.copy(isRecommendationsRefreshing = true)
            runCatching { api.recommendations() }
                .onSuccess { (raw, response) ->
                    recommendationsCache.writeText(raw)
                    state = state.copy(
                        recommendationBatch = response.batch,
                        recommendations = response.items,
                        isRecommendationsRefreshing = false,
                    )
                    beginRecommendationSpeechIfNeeded()
                }
                .onFailure { error ->
                    state = state.copy(
                        isRecommendationsRefreshing = false,
                        errorMessage = if (state.recommendations.isEmpty()) error.userMessage() else state.errorMessage,
                    )
                }
        }
    }

    fun activateRecommendation(recommendation: RecommendationItem) {
        stopRecommendationSpeech()
        val item = recommendation.launch
        if (item.isBrowsable) {
            state = state.copy(destination = Destination.LIBRARY)
            openLibrary(LibraryLocation(
                categoryId = item.categoryId.orEmpty(),
                title = item.title,
                sourceIndex = item.sourceIndex,
                path = item.path.orEmpty(),
                backdrop = item.backdrop,
                poster = item.seriesPoster ?: item.seasonPoster ?: item.poster,
                summary = item.summary,
                mediaType = item.mediaType,
            ))
        } else openDetails(item)
    }

    fun play(item: MediaItem, resume: Boolean) {
        if (state.isDemo) {
            startPlayback(item.copy(nzbUrl = null), resume)
            return
        }
        if (!item.nzbUrl.isNullOrBlank()) {
            val api = client ?: return
            viewModelScope.launch {
                state = state.copy(isPreparingPlayback = true)
                runCatching { api.prepareDiscovery(item, item) }
                    .onSuccess { files ->
                        state = state.copy(isPreparingPlayback = false)
                        files.getOrNull(item.discoverStreamIndex.coerceIn(0, (files.size - 1).coerceAtLeast(0)))
                            ?.let { startPlayback(it.playbackItem, resume) }
                            ?: run { state = state.copy(errorMessage = "The saved Discover stream is no longer available.") }
                    }
                    .onFailure { state = state.copy(isPreparingPlayback = false, errorMessage = it.userMessage()) }
            }
            return
        }
        startPlayback(item, resume)
    }

    private fun startPlayback(item: MediaItem, resume: Boolean, holdDiscoveryOverlay: Boolean = false) {
        if (state.isDemo) {
            val durationMs = DemoCatalog.playbackDurationMs
            val resumePositionMs = if (resume) {
                (durationMs * item.progressPercent.coerceIn(0.0, 95.0) / 100.0).toLong()
            } else 0L
            val resourceUri = "android.resource://${getApplication<Application>().packageName}/${R.raw.tater_demo_reel}"
            state = state.copy(
                isPreparingPlayback = false,
                isPreparingDiscovery = if (holdDiscoveryOverlay) false else state.isPreparingDiscovery,
                selectedMedia = null,
                playback = PlaybackSession(
                    item = item.copy(
                        streamUrl = resourceUri,
                        durationMs = durationMs,
                        viewOffsetMs = resumePositionMs,
                    ),
                    plan = DemoCatalog.playbackPlan(resourceUri),
                    startPositionMs = resumePositionMs,
                ),
                errorMessage = null,
            )
            return
        }
        val api = client
        if (api == null) {
            state = state.copy(
                isPreparingDiscovery = if (holdDiscoveryOverlay) false else state.isPreparingDiscovery,
                errorMessage = "Pair with your Tater Tube Server to play this title.",
            )
            return
        }
        if (state.isPreparingPlayback) {
            if (holdDiscoveryOverlay) state = state.copy(isPreparingDiscovery = false)
            return
        }
        viewModelScope.launch {
            state = state.copy(isPreparingPlayback = true, errorMessage = null)
            val playbackCapabilities = DeviceCapabilities.read(getApplication()).also { capabilities = it }
            runCatching { api.playbackPlan(item, playbackCapabilities) }
                .onSuccess { plan ->
                    val duration = item.durationMs.takeIf { it > 0 }
                        ?: plan.source.durationSeconds?.times(1000)?.toLong().orZero()
                    val playable = item.copy(
                        durationMs = duration,
                        channelLogoUrl = item.channelLogoUrl?.let(api::resolveUrl),
                    )
                    state = state.copy(
                        isPreparingPlayback = false,
                        selectedMedia = null,
                        playback = PlaybackSession(
                            item = playable,
                            plan = plan,
                            startPositionMs = if (resume) item.viewOffsetMs else 0,
                        ),
                    )
                    runCatching { api.savePlayState(playable, state.playback?.startPositionMs ?: 0, duration, false, true) }
                }
                .onFailure { error -> state = state.copy(
                    isPreparingPlayback = false,
                    isPreparingDiscovery = if (holdDiscoveryOverlay) false else state.isPreparingDiscovery,
                    errorMessage = error.userMessage(),
                ) }
        }
    }

    fun stopPlayback(positionMs: Long, durationMs: Long, completed: Boolean) {
        val session = state.playback ?: return
        state = state.copy(playback = null, isPreparingDiscovery = false)
        updateVisibleProgress(session.item, positionMs, durationMs, completed)
        state.home?.let { home ->
            viewModelScope.launch { WatchNextPublisher.publish(getApplication(), home.continueWatching) }
        }
        client?.let { api ->
            viewModelScope.launch {
                runCatching { api.savePlayState(session.item, positionMs, durationMs, completed, false) }
                val nextEpisode = if (
                    completed &&
                    session.item.isEpisode &&
                    session.item.categoryId?.startsWith("local:", ignoreCase = true) == true
                ) {
                    runCatching { api.nextEpisode(session.item) }.getOrNull()
                } else null
                refreshHome(showError = false)
                state.libraryStack.lastOrNull()?.let { loadLibraryPage(it, force = true) }
                if (state.home?.capabilities?.taterLink == true) refreshRecommendations()
                if (nextEpisode?.streamUrl != null) startPlayback(nextEpisode, resume = false)
            }
        }
    }

    fun changeAudioTrack(trackIndex: Int, positionMs: Long) {
        val session = state.playback ?: return
        val api = client ?: return
        if (state.isPreparingPlayback) return
        viewModelScope.launch {
            state = state.copy(isPreparingPlayback = true)
            runCatching { api.playbackPlan(session.item, capabilities, audioTrack = trackIndex) }
                .onSuccess { plan ->
                    state = state.copy(
                        isPreparingPlayback = false,
                        playback = PlaybackSession(session.item, plan, positionMs.coerceAtLeast(0)),
                    )
                }
                .onFailure { error ->
                    state = state.copy(isPreparingPlayback = false, errorMessage = error.userMessage())
                }
        }
    }

    fun clearProgress(item: MediaItem) {
        val api = client ?: return
        viewModelScope.launch {
            runCatching { api.clearPlayState(item) }
                .onSuccess {
                    state = state.copy(selectedMedia = null)
                    refreshHome()
                    state.libraryStack.lastOrNull()?.let { loadLibraryPage(it, force = true) }
                }
                .onFailure { state = state.copy(errorMessage = it.userMessage()) }
        }
    }

    fun dismissError() {
        state = state.copy(errorMessage = null)
    }

    fun disconnect() {
        stopRecommendationSpeech()
        viewModelScope.launch { WatchNextPublisher.clear(getApplication()) }
        credentials.clear()
        cacheRoot.deleteRecursively()
        cacheRoot.mkdirs()
        connection = null
        client = null
        state = PlayerUiState(phase = AppPhase.PAIRING)
    }

    fun artworkUrl(item: MediaItem): String? = item.preferredArtwork?.let(::resolveArtworkUrl)
    fun wideArtworkUrl(item: MediaItem): String? = item.wideArtwork?.let(::resolveArtworkUrl)
    fun resolveArtworkUrl(value: String): String = client?.resolveUrl(value) ?: value
    fun guideArtworkUrl(program: LiveProgram): String? = client?.guideArtworkUrl(program) ?: program.artwork

    private suspend fun start() {
        val saved = credentials.load()
        if (saved == null) {
            state = state.copy(phase = AppPhase.PAIRING)
            return
        }
        connect(saved)
        state = state.copy(
            phase = AppPhase.READY,
            home = readCache(homeCache, ModelParser::home),
            libraryRows = readCache(libraryRowsCache, ModelParser::libraryRows).orEmpty(),
            liveGuide = readCache(guideCache, ModelParser::liveGuide),
            discoverCategories = readCache(discoverCatalogCache, ModelParser::discoverCategories).orEmpty(),
        )
        readCache(recommendationsCache, ModelParser::recommendations)?.let {
            state = state.copy(recommendationBatch = it.batch, recommendations = it.items)
        }
        state.home?.let { home ->
            viewModelScope.launch { WatchNextPublisher.publish(getApplication(), home.continueWatching) }
        }
        openPendingDeepLink()
        refreshHome(showError = state.home == null)
        reportCapabilities()
    }

    private fun connect(saved: SavedConnection) {
        connection = saved
        client = TaterApiClient(saved.serverUrl, saved.token)
        capabilities = DeviceCapabilities.read(getApplication())
    }

    private fun openPendingDeepLink() {
        val identifier = pendingDeepLinkId ?: return
        val item = state.home?.continueWatching?.firstOrNull { it.id == identifier } ?: return
        pendingDeepLinkId = null
        play(item, resume = true)
    }

    private fun reportCapabilities() {
        val api = client ?: return
        viewModelScope.launch {
            capabilities = DeviceCapabilities.read(getApplication())
            runCatching { api.reportCapabilities(capabilities) }
        }
    }

    private fun beginRecommendationSpeechIfNeeded() {
        if (state.isDemo || state.destination != Destination.TATER_PICKS || state.recommendations.isEmpty()) return
        val batch = state.recommendationBatch ?: return
        if (batch.id.isBlank() || batch.id == spokenBatchId) return
        spokenBatchId = batch.id
        startRecommendationSpeech(batch.id)
    }

    private fun startRecommendationSpeech(batchId: String) {
        val api = client ?: return
        stopRecommendationSpeech(resetBatch = false)
        speechJob = viewModelScope.launch {
            state = state.copy(speechState = TaterSpeechState.Loading)
            delay(700)
            runCatching {
                var request = api.createRecommendationSpeech(batchId)
                require(request.id.matches(Regex("^[A-Za-z0-9_-]{1,128}$"))) { "Tater's voice returned an invalid request." }
                speechRequestId = request.id
                val startedAt = System.currentTimeMillis()
                while (isActive && System.currentTimeMillis() - startedAt < 90_000) {
                    when (request.status.lowercase()) {
                        "ready" -> return@runCatching api.recommendationSpeechAudio(request.id)
                        "failed", "error", "canceled", "cancelled", "expired" ->
                            error(request.error ?: "Tater's voice is unavailable right now.")
                    }
                    if (request.status.equals("pending", true) && System.currentTimeMillis() - startedAt >= 15_000) {
                        error("Tater's voice is not available right now. Your picks are ready below.")
                    }
                    delay(500)
                    request = api.recommendationSpeechStatus(request.id)
                }
                error("Tater's voice is taking a little too long. Your picks are ready below.")
            }.onSuccess(::playSpeech)
                .onFailure { if (isActive) state = state.copy(speechState = TaterSpeechState.Failed(it.userMessage())) }
        }
    }

    private fun playSpeech(audio: ByteArray) {
        if (audio.size < 12 || !audio.copyOfRange(0, 4).contentEquals("RIFF".toByteArray()) ||
            !audio.copyOfRange(8, 12).contentEquals("WAVE".toByteArray())) {
            state = state.copy(speechState = TaterSpeechState.Failed("The voice message could not be played."))
            return
        }
        val file = File(cacheRoot, "tater-picks.wav").apply { writeBytes(audio) }
        runCatching {
            MediaPlayer().also { player ->
                speechPlayer = player
                player.setDataSource(file.absolutePath)
                player.setOnPreparedListener {
                    state = state.copy(speechState = TaterSpeechState.Speaking)
                    it.start()
                }
                player.setOnCompletionListener { stopRecommendationSpeech(resetBatch = false) }
                player.setOnErrorListener { _, _, _ ->
                    state = state.copy(speechState = TaterSpeechState.Failed("The voice message could not be played."))
                    true
                }
                player.prepareAsync()
            }
        }.onFailure { state = state.copy(speechState = TaterSpeechState.Failed(it.userMessage())) }
    }

    fun stopRecommendationSpeech(resetBatch: Boolean = true) {
        speechJob?.cancel()
        speechJob = null
        speechPlayer?.runCatching { stop() }
        speechPlayer?.release()
        speechPlayer = null
        speechRequestId?.let { id -> client?.let { api -> viewModelScope.launch { api.cancelRecommendationSpeech(id) } } }
        speechRequestId = null
        if (resetBatch) spokenBatchId = null
        if (state.speechState !is TaterSpeechState.Idle) state = state.copy(speechState = TaterSpeechState.Idle)
    }

    private fun recentlyAddedLocation(item: MediaItem): LibraryLocation? {
        val first = item.recentItems.firstOrNull() ?: return null
        val episodePath = first.path?.trim('/') ?: return null
        val parts = episodePath.split('/').filter(String::isNotBlank)
        if (parts.size < 2) return null
        val parentPath = parts.dropLast(1).joinToString("/")
        return LibraryLocation(
            categoryId = first.categoryId ?: item.categoryId.orEmpty(),
            title = parts.dropLast(1).lastOrNull() ?: item.title,
            sourceIndex = first.sourceIndex,
            path = parentPath,
            backdrop = item.backdrop ?: first.backdrop,
            poster = item.seriesPoster ?: item.poster ?: first.seriesPoster ?: first.poster,
            summary = item.summary,
            mediaType = "season",
            initialFocusItemId = first.id,
        )
    }

    private fun updateVisibleProgress(item: MediaItem, positionMs: Long, durationMs: Long, completed: Boolean) {
        val home = state.home ?: return
        val percent = if (completed || durationMs <= 0) 0.0 else positionMs.toDouble() / durationMs * 100.0
        fun update(list: List<MediaItem>) = list.map {
            if (it.matches(item)) it.copy(
                progressPercent = percent.coerceIn(0.0, 100.0),
                viewOffsetMs = if (completed) 0 else positionMs,
                durationMs = durationMs,
            ) else it
        }.filterNot { completed && it.matches(item) }

        val pages = state.libraryPages.mapValues { (_, page) -> page.copy(items = update(page.items)) }
        state = state.copy(
            home = home.copy(
                continueWatching = update(home.continueWatching),
                recentlyAdded = update(home.recentlyAdded),
            ),
            libraryPages = pages,
        )
    }

    private fun MediaItem.matches(other: MediaItem): Boolean = id == other.id ||
        (!playStateId.isNullOrBlank() && playStateId == other.playStateId)

    private fun cacheFile(group: String, key: String): File {
        val directory = File(cacheRoot, group).apply { mkdirs() }
        val digest = MessageDigest.getInstance("SHA-256").digest(key.toByteArray())
            .joinToString("") { "%02x".format(it) }
        return File(directory, "$digest.json")
    }

    private fun <T> readCache(file: File, parser: (String) -> T): T? =
        runCatching { parser(file.readText()) }.getOrNull()

    private fun Long?.orZero(): Long = this ?: 0L
    private fun Throwable.userMessage(): String = message?.takeIf { it.isNotBlank() }
        ?: "Tater Tube Player could not complete that request."

    override fun onCleared() {
        stopRecommendationSpeech()
    }
}
