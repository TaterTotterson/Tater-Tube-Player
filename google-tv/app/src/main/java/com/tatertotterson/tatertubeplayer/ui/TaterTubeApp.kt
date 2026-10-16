package com.tatertotterson.tatertubeplayer.ui

import android.view.KeyEvent
import androidx.activity.compose.BackHandler
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.focusGroup
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusProperties
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.focus.focusRestorer
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.sp
import androidx.tv.material3.Text
import com.tatertotterson.tatertubeplayer.R
import com.tatertotterson.tatertubeplayer.model.LibraryLocation
import com.tatertotterson.tatertubeplayer.model.MediaItem
import com.tatertotterson.tatertubeplayer.model.PlayerHome
import com.tatertotterson.tatertubeplayer.playback.PlaybackScreen
import com.tatertotterson.tatertubeplayer.ui.components.GlassSurface
import com.tatertotterson.tatertubeplayer.ui.components.LocalTopNavigationFocused
import com.tatertotterson.tatertubeplayer.ui.components.MediaCard
import com.tatertotterson.tatertubeplayer.ui.components.RestoreInitialFocus
import com.tatertotterson.tatertubeplayer.ui.components.SectionHeading
import com.tatertotterson.tatertubeplayer.ui.components.TaterArtwork
import com.tatertotterson.tatertubeplayer.ui.components.TaterButton
import com.tatertotterson.tatertubeplayer.ui.theme.TaterColors
import com.tatertotterson.tatertubeplayer.ui.theme.taterFocusGlow
import kotlinx.coroutines.delay
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import androidx.compose.runtime.rememberCoroutineScope
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import kotlin.math.min

@Composable
fun TaterTubeApp(viewModel: PlayerViewModel) {
    TvDesignViewport { TaterTubeAppContent(viewModel) }
}

@Composable
private fun TvDesignViewport(content: @Composable () -> Unit) {
    val configuration = LocalConfiguration.current
    val systemDensity = LocalDensity.current
    val pixelWidth = configuration.screenWidthDp * systemDensity.density
    val pixelHeight = configuration.screenHeightDp * systemDensity.density
    val designDensity = min(pixelWidth / 1920f, pixelHeight / 1080f).coerceAtLeast(0.5f)
    CompositionLocalProvider(
        LocalDensity provides Density(designDensity, systemDensity.fontScale),
        content = content,
    )
}

@Composable
private fun TaterTubeAppContent(viewModel: PlayerViewModel) {
    val state = viewModel.state

    if (state.playback != null) {
        Box(Modifier.fillMaxSize()) {
            PlaybackScreen(
                session = state.playback,
                processingInfo = state.playbackProcessing,
                token = viewModel.token,
                liveGuide = state.liveGuide,
                onExit = viewModel::stopPlayback,
                onAudioTrackChange = viewModel::changeAudioTrack,
                onFirstFrame = viewModel::finishDiscoveryPreparation,
                onPlaybackFailure = viewModel::handlePlaybackFailure,
            )
            if (state.isPreparingDiscovery) DiscoveryPreparingOverlay()
            state.errorMessage?.let { message ->
                MessageOverlay(message = message, onDismiss = viewModel::dismissError)
            }
        }
        return
    }

    when (state.phase) {
        AppPhase.STARTING -> StartingScreen()
        AppPhase.PAIRING -> PairingScreen(
            busy = state.isRefreshing,
            onPair = viewModel::pair,
            onDemo = viewModel::enterDemo,
        )
        AppPhase.READY -> MainShell(viewModel)
    }

    state.errorMessage?.let { message ->
        MessageOverlay(message = message, onDismiss = viewModel::dismissError)
    }
}

@Composable
private fun StartingScreen() {
    Column(
        Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Image(
            painter = painterResource(R.drawable.tater_tube_logo),
            contentDescription = "Tater Tube",
            contentScale = ContentScale.Fit,
            modifier = Modifier.width(520.dp),
        )
        Spacer(Modifier.height(18.dp))
        Text("WAKING THE TATERS…", color = TaterColors.OrangeBright, fontSize = 18.sp, fontWeight = FontWeight.Bold)
    }
}

@Composable
private fun ServerBootstrapScreen(
    busy: Boolean,
    onRetry: () -> Unit,
    onDisconnect: () -> Unit,
) {
    val retryFocus = remember { FocusRequester() }
    Column(
        Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Image(
            painter = painterResource(R.drawable.tater_tube_logo),
            contentDescription = "Tater Tube",
            contentScale = ContentScale.Fit,
            modifier = Modifier.width(520.dp),
        )
        Spacer(Modifier.height(18.dp))
        Text(
            if (busy) "WAKING THE TATERS…" else "THE SERVER TOOK A NAP",
            color = TaterColors.OrangeBright,
            fontSize = 18.sp,
            fontWeight = FontWeight.Bold,
        )
        if (!busy) {
            Spacer(Modifier.height(18.dp))
            Text(
                "This player is paired. Try loading the library again, or pair with another server.",
                color = TaterColors.SecondaryText,
                fontSize = 16.sp,
            )
            Spacer(Modifier.height(24.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                TaterButton(
                    text = "Try Again",
                    onClick = onRetry,
                    modifier = Modifier.width(220.dp).focusRequester(retryFocus),
                )
                TaterButton(
                    text = "Pair Another Server",
                    onClick = onDisconnect,
                    modifier = Modifier.width(280.dp),
                )
            }
            LaunchedEffect(Unit) { retryFocus.requestFocus() }
        }
    }
}

@Composable
private fun PairingScreen(
    busy: Boolean,
    onPair: (String, String) -> Unit,
    onDemo: () -> Unit,
) {
    var server by remember { mutableStateOf("") }
    var pin by remember { mutableStateOf("") }
    val serverFocus = remember { FocusRequester() }

    Box(
        Modifier
            .fillMaxSize()
            .background(Color.Black)
            .background(
                Brush.radialGradient(
                    colors = listOf(TaterColors.Orange.copy(alpha = 0.16f), Color.Transparent),
                    center = Offset(1430f, 520f),
                    radius = 760f,
                )
            )
    ) {
        Row(
            Modifier
                .fillMaxSize()
                .padding(horizontal = 118.dp, vertical = 84.dp),
            horizontalArrangement = Arrangement.spacedBy(108.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(
                Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(20.dp),
                horizontalAlignment = Alignment.Start,
            ) {
                Text(
                    "TATER TUBE PLAYER",
                    color = TaterColors.OrangeBright,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 1.6.sp,
                )
                Image(
                    painter = painterResource(R.drawable.tater_tube_logo),
                    contentDescription = "Tater Tube",
                    contentScale = ContentScale.Fit,
                    modifier = Modifier.width(680.dp).height(300.dp),
                )
                Text(
                    "Your server. Your screen.",
                    color = Color.White,
                    fontSize = 44.sp,
                    fontWeight = FontWeight.Bold,
                )
                Text(
                    "Bring your Tater Tube library, channels, and watch history to the biggest screen in the house.",
                    color = TaterColors.SecondaryText,
                    fontSize = 20.sp,
                    lineHeight = 29.sp,
                    modifier = Modifier.width(690.dp),
                )
            }

            GlassSurface(Modifier.width(620.dp), cornerRadius = 30.dp) {
                Column(
                    Modifier.padding(horizontal = 40.dp, vertical = 38.dp),
                    verticalArrangement = Arrangement.spacedBy(19.dp),
                ) {
                    Text("PAIR YOUR PLAYER", color = TaterColors.OrangeBright, fontSize = 15.sp, fontWeight = FontWeight.Bold)
                    Text("Connect to Tater Tube", color = Color.White, fontSize = 30.sp, fontWeight = FontWeight.Bold)
                    Text(
                        "Enter the server address and temporary pairing code shown in Tater Tube Server.",
                        color = TaterColors.SecondaryText,
                        fontSize = 16.sp,
                        lineHeight = 23.sp,
                    )
                    PairingField(
                        value = server,
                        onValueChange = { server = it },
                        label = "Server address",
                        hint = "10.0.0.20:8000",
                        modifier = Modifier.focusRequester(serverFocus),
                    )
                    PairingField(
                        value = pin,
                        onValueChange = { pin = it.filter(Char::isDigit).take(8) },
                        label = "Pairing code",
                        hint = "000000",
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    )
                    Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                        TaterButton(
                            text = if (busy) "Pairing…" else "Pair",
                            onClick = { onPair(server, pin) },
                            enabled = !busy,
                            modifier = Modifier.weight(1f),
                        )
                        TaterButton(text = "Try Demo", onClick = onDemo, modifier = Modifier.weight(1f))
                    }
                    Text(
                        "No server handy? Try Demo uses fictional media and does not connect anywhere.",
                        color = TaterColors.SecondaryText.copy(alpha = 0.78f),
                        fontSize = 14.sp,
                    )
                }
            }
        }
    }

    LaunchedEffect(Unit) { serverFocus.requestFocus() }
}

@Composable
private fun PairingField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    hint: String,
    modifier: Modifier = Modifier,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
) {
    var focused by remember { mutableStateOf(false) }
    Column(verticalArrangement = Arrangement.spacedBy(7.dp)) {
        Text(label, color = TaterColors.SecondaryText, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            singleLine = true,
            keyboardOptions = keyboardOptions,
            textStyle = TextStyle(color = Color.White, fontSize = 19.sp),
            modifier = modifier
                .fillMaxWidth()
                .onFocusChanged { focused = it.isFocused }
                .background(
                    color = Color.Black.copy(alpha = 0.72f),
                    shape = RoundedCornerShape(16.dp),
                )
                .padding(horizontal = 18.dp, vertical = 15.dp),
            decorationBox = { inner ->
                Box {
                    if (value.isBlank()) Text(hint, color = Color.White.copy(alpha = 0.35f), fontSize = 19.sp)
                    inner()
                }
            },
        )
        Box(
            Modifier
                .fillMaxWidth()
                .height(if (focused) 3.dp else 1.dp)
                .background(if (focused) TaterColors.Orange else Color.White.copy(alpha = 0.12f))
        )
    }
}

@Composable
private fun MainShell(viewModel: PlayerViewModel) {
    val state = viewModel.state
    var topNavigationFocused by remember { mutableStateOf(false) }
    var requestedTopDestination by remember { mutableStateOf(Destination.HOME) }
    var topFocusRequestRevision by remember { mutableIntStateOf(0) }
    val hasNestedNavigation = state.libraryStack.isNotEmpty() ||
        (state.destination == Destination.DISCOVER && state.discoverStage != DiscoverStage.CATEGORIES)

    BackHandler(
        enabled = state.selectedMedia != null || hasNestedNavigation ||
            !topNavigationFocused || state.destination != Destination.HOME
    ) {
        when {
            state.selectedMedia != null -> viewModel.handleBack()
            hasNestedNavigation && !topNavigationFocused -> viewModel.handleBack()
            topNavigationFocused && state.destination != Destination.HOME -> {
                viewModel.selectDestination(Destination.HOME)
                requestedTopDestination = Destination.HOME
                topFocusRequestRevision++
            }
            !topNavigationFocused -> {
                requestedTopDestination = state.destination
                topFocusRequestRevision++
            }
        }
    }

    Box(Modifier.fillMaxSize().background(Color.Black)) {
        CompositionLocalProvider(LocalTopNavigationFocused provides topNavigationFocused) {
            Box(Modifier.fillMaxSize()) {
                when (state.destination) {
                    Destination.HOME -> HomeScreen(viewModel)
                    Destination.LIVE_TV -> LiveGuideScreen(viewModel)
                    Destination.MOVIES -> LibraryScreen(viewModel, LibraryLocation.AllMovies)
                    Destination.SERIES -> LibraryScreen(viewModel, LibraryLocation.AllShows)
                    Destination.DISCOVER -> DiscoveryScreen(viewModel)
                    Destination.TATER_PICKS -> TaterPicksScreen(viewModel)
                    Destination.SETTINGS -> SettingsScreen(viewModel)
                }
            }
        }

        TopNavigation(
            viewModel = viewModel,
            requestedDestination = requestedTopDestination,
            focusRequestRevision = topFocusRequestRevision,
            onFocusWithinChanged = { topNavigationFocused = it },
        )

        state.selectedMedia?.let { item ->
            MediaDetailOverlay(item = item, viewModel = viewModel)
        }
    }
}

@Composable
private fun TopNavigation(
    viewModel: PlayerViewModel,
    requestedDestination: Destination,
    focusRequestRevision: Int,
    onFocusWithinChanged: (Boolean) -> Unit,
) {
    val state = viewModel.state
    val home = state.home
    val destinations = buildList {
        add(Destination.HOME)
        if (home?.capabilities?.tubeTV == true) add(Destination.LIVE_TV)
        add(Destination.MOVIES)
        add(Destination.SERIES)
        if (home?.capabilities?.newznab == true) add(Destination.DISCOVER)
        if (home?.capabilities?.taterLink == true) add(Destination.TATER_PICKS)
    }
    val allDestinations = destinations + Destination.SETTINGS
    val focusRequesters = remember { Destination.entries.associateWith { FocusRequester() } }
    var focusedDestination by remember { mutableStateOf<Destination?>(null) }
    var enteringNavigation by remember { mutableStateOf(true) }

    LaunchedEffect(focusRequestRevision, requestedDestination) {
        if (focusRequestRevision <= 0) return@LaunchedEffect
        delay(20)
        runCatching { focusRequesters.getValue(requestedDestination).requestFocus() }
    }

    Row(
        Modifier
            .fillMaxWidth()
            .height(44.dp)
            .onFocusChanged {
                onFocusWithinChanged(it.hasFocus)
                if (!it.hasFocus) {
                    focusedDestination = null
                    enteringNavigation = true
                }
            }
            .focusRestorer(focusRequesters.getValue(state.destination))
            .focusGroup()
            .onPreviewKeyEvent { event ->
                val native = event.nativeKeyEvent
                if (native.action != KeyEvent.ACTION_DOWN) return@onPreviewKeyEvent false
                val step = when (native.keyCode) {
                    KeyEvent.KEYCODE_DPAD_LEFT -> -1
                    KeyEvent.KEYCODE_DPAD_RIGHT -> 1
                    else -> 0
                }
                if (step == 0 || focusedDestination == null) return@onPreviewKeyEvent false
                val currentIndex = allDestinations.indexOf(focusedDestination)
                val target = allDestinations.getOrNull(currentIndex + step) ?: return@onPreviewKeyEvent true
                viewModel.selectDestination(target)
                focusedDestination = target
                runCatching { focusRequesters.getValue(target).requestFocus() }
                true
            }
            .background(
                Brush.verticalGradient(
                    listOf(
                        Color.Black.copy(alpha = .97f),
                        Color.Black.copy(alpha = .88f),
                        Color.Black.copy(alpha = .50f),
                    )
                )
            )
            .padding(horizontal = 54.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Start,
    ) {
        Spacer(Modifier.width(345.dp))
        destinations.forEach { destination ->
            Box(Modifier.width(188.dp), contentAlignment = Alignment.Center) {
                TopNavigationItem(
                    title = if (destination == Destination.LIVE_TV) "TUBE TV" else destination.label.uppercase(),
                    selected = state.destination == destination,
                    modifier = Modifier.focusRequester(focusRequesters.getValue(destination)),
                    onFocusChanged = { focused ->
                        if (focused) {
                            val entering = enteringNavigation
                            enteringNavigation = false
                            focusedDestination = destination
                            onFocusWithinChanged(true)
                            if (entering && destination != state.destination) {
                                focusedDestination = state.destination
                                runCatching { focusRequesters.getValue(state.destination).requestFocus() }
                            } else if (!entering && destination != state.destination) {
                                viewModel.selectDestination(destination)
                            }
                        }
                    },
                    onClick = { viewModel.selectDestination(destination) },
                )
            }
        }
        Spacer(Modifier.width(154.dp))
        Box(Modifier.width(44.dp), contentAlignment = Alignment.Center) {
            TopNavigationItem(
                title = "⚙",
                selected = state.destination == Destination.SETTINGS,
                modifier = Modifier.focusRequester(focusRequesters.getValue(Destination.SETTINGS)),
                onFocusChanged = { focused ->
                    if (focused) {
                        val entering = enteringNavigation
                        enteringNavigation = false
                        focusedDestination = Destination.SETTINGS
                        onFocusWithinChanged(true)
                        if (entering && state.destination != Destination.SETTINGS) {
                            focusedDestination = state.destination
                            runCatching { focusRequesters.getValue(state.destination).requestFocus() }
                        } else if (!entering && state.destination != Destination.SETTINGS) {
                            viewModel.selectDestination(Destination.SETTINGS)
                        }
                    }
                },
                onClick = { viewModel.selectDestination(Destination.SETTINGS) },
                compact = true,
            )
        }
    }
}

@Composable
private fun TopNavigationItem(
    title: String,
    selected: Boolean,
    modifier: Modifier = Modifier,
    onFocusChanged: (Boolean) -> Unit,
    onClick: () -> Unit,
    compact: Boolean = false,
) {
    var focused by remember { mutableStateOf(false) }
    var focusVisible by remember { mutableStateOf(false) }

    LaunchedEffect(focused) {
        if (!focused) {
            focusVisible = false
        } else {
            // Content screens briefly hand focus through the selected top tab
            // while their remembered card is reattached. Do not present that
            // transient handoff as navigation; intentional menu focus remains
            // visible once it settles.
            delay(140)
            focusVisible = true
        }
    }

    Column(
        modifier
            .onFocusChanged {
                focused = it.isFocused
                onFocusChanged(it.isFocused)
            }
            .clickable(onClick = onClick)
            .graphicsLayer {
                val scale = if (focusVisible) 1.06f else 1f
                scaleX = scale
                scaleY = scale
            }
            .padding(horizontal = if (compact) 8.dp else 3.dp, vertical = 3.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(7.dp)) {
            if (selected && !compact) {
                Box(Modifier.size(6.dp).clip(CircleShape).background(TaterColors.OrangeBright))
            }
            Text(
                title,
                color = when {
                    focusVisible -> TaterColors.OrangeBright
                    selected -> Color.White
                    else -> Color.White.copy(alpha = .72f)
                },
                fontSize = if (compact) 21.sp else 16.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = if (compact) 0.sp else 1.sp,
                maxLines = 1,
            )
        }
        Box(
            Modifier
                .width(if (compact) 30.dp else 54.dp)
                .height(2.dp)
                .background(if (selected || focusVisible) TaterColors.Orange else Color.Transparent, CircleShape)
        )
    }
}

@Composable
private fun HomeScreen(viewModel: PlayerViewModel) {
    val state = viewModel.state
    val home = state.home
    if (home == null) {
        ServerBootstrapScreen(
            busy = state.isRefreshing,
            onRetry = { viewModel.refreshHome(showError = true) },
            onDisconnect = viewModel::disconnect,
        )
        return
    }

    val initialFocus = remember { FocusRequester() }
    val shelfListState = rememberLazyListState()
    val topNavigationFocused = LocalTopNavigationFocused.current
    var homeClock by remember { mutableLongStateOf(System.currentTimeMillis()) }
    var focusedHeroItem by remember { mutableStateOf<MediaItem?>(null) }
    val continueLocation = state.libraryRows
        .firstOrNull { it.entry.type.equals("continue", true) }
        ?.entry
        ?.let(LibraryLocation::fromEntry)
        ?: LibraryLocation("", "Continue Watching", continueWatching = true)
    val recentLocation = state.libraryRows
        .firstOrNull { it.entry.id.equals("local-discover:recent", true) }
        ?.entry
        ?.let(LibraryLocation::fromEntry)
        ?: LibraryLocation("local-discover:recent", "Recently Added")
    val browseRows = state.libraryRows.filter { row ->
        val id = row.entry.id.lowercase()
        val type = row.entry.type.orEmpty().lowercase()
        row.items.isNotEmpty() &&
            id != "local-discover:movies" &&
            id != "local-discover:series" &&
            id != "local-discover:recent" &&
            type != "continue" &&
            type != "local"
    }
    val homeShelves = buildList {
        if (home.continueWatching.isNotEmpty()) {
            add(
                HomeShelfRow(
                    id = "home-shelf-continue",
                    title = "CONTINUE WATCHING",
                    items = home.continueWatching,
                    location = continueLocation,
                    kind = HomeShelfKind.CONTINUE_WATCHING,
                )
            )
        }
        if (home.recentlyAdded.isNotEmpty()) {
            add(
                HomeShelfRow(
                    id = "home-shelf-recent",
                    title = "RECENTLY ADDED",
                    items = home.recentlyAdded,
                    location = recentLocation,
                    kind = HomeShelfKind.RECENTLY_ADDED,
                )
            )
        }
        browseRows.forEach { row ->
            add(
                HomeShelfRow(
                    id = "home-library-${row.entry.id}",
                    title = row.title.uppercase(),
                    items = row.items,
                    location = LibraryLocation.fromEntry(row.entry),
                    kind = HomeShelfKind.LIBRARY,
                )
            )
        }
    }
    val heroItem = focusedHeroItem ?: homeShelves.firstOrNull()?.items?.firstOrNull()
    val homeCoroutineScope = rememberCoroutineScope()
    val shelfFocusRequesters = remember(homeShelves.map(HomeShelfRow::id)) {
        List(homeShelves.size) { index -> if (index == 0) initialFocus else FocusRequester() }
    }
    var focusedShelfIndex by remember { mutableIntStateOf(0) }
    var detailWasOpen by remember { mutableStateOf(false) }
    var restoringDetailFocus by remember { mutableStateOf(false) }
    var verticalScrollJob by remember { mutableStateOf<Job?>(null) }

    fun moveToShelf(fromIndex: Int, step: Int): Boolean {
        val targetIndex = fromIndex + step
        val targetRequester = shelfFocusRequesters.getOrNull(targetIndex) ?: return false
        verticalScrollJob?.cancel()
        verticalScrollJob = homeCoroutineScope.launch {
            // Place every destination shelf at the same height as the first
            // shelf, then restore that exact alignment after Android's focus
            // system performs its automatic bring-into-view pass.
            shelfListState.scrollToItem(targetIndex)
            withFrameNanos { }
            targetRequester.requestFocus()
            withFrameNanos { }
            shelfListState.scrollToItem(targetIndex)
        }
        return true
    }

    Box(Modifier.fillMaxSize()) {
        if (heroItem != null) {
            TaterArtwork(
                item = heroItem,
                artworkUrl = viewModel.wideArtworkUrl(heroItem),
                token = viewModel.token,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(808.dp)
                    .offset(y = 0.dp),
                contentScale = ContentScale.Crop,
                alignment = Alignment.TopCenter,
                backgroundColor = Color.Black,
            )
        }
        Box(
            Modifier
                .fillMaxWidth()
                .height(808.dp)
                .offset(y = 0.dp)
                .background(
                    Brush.horizontalGradient(
                        listOf(Color.Black.copy(alpha = .98f), Color.Black.copy(alpha = .70f), Color.Transparent)
                    )
                )
                .background(
                    Brush.verticalGradient(
                        listOf(Color.Transparent, Color.Black.copy(alpha = .28f), Color.Black)
                    )
                )
        )

        Column(Modifier.fillMaxSize().padding(top = 78.dp)) {
            Box(Modifier.padding(horizontal = 70.dp)) {
                CinematicHomeHero(heroItem, homeClock)
            }

            Box(Modifier.fillMaxWidth().weight(1f)) {
                val showFixedFocus = !topNavigationFocused &&
                    state.selectedMedia == null &&
                    !detailWasOpen &&
                    !restoringDetailFocus
                val focusShape = RoundedCornerShape(22.dp)
                val fixedFocusModifier = Modifier
                    .offset(x = 78.dp, y = 90.dp)
                    .width(340.dp)
                    .height(202.dp)
                    .graphicsLayer {
                        scaleX = 1.045f
                        scaleY = 1.045f
                    }

                // The home focus frame is anchored to the viewport. Shelves
                // move behind it, so vertical navigation never drags the glow.
                Box(fixedFocusModifier.taterFocusGlow(showFixedFocus, focusShape))

                LazyColumn(
                    Modifier.fillMaxSize().clipToBounds(),
                    state = shelfListState,
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(
                        start = 70.dp,
                        end = 70.dp,
                        top = 18.dp,
                        bottom = 360.dp,
                    ),
                    verticalArrangement = Arrangement.spacedBy(42.dp),
                ) {
                    itemsIndexed(homeShelves, key = { _, shelf -> shelf.id }) { index, shelf ->
                        val clickHandler: ((MediaItem) -> Unit)? = when (shelf.kind) {
                            HomeShelfKind.CONTINUE_WATCHING -> null
                            HomeShelfKind.RECENTLY_ADDED -> { item ->
                                if (item.isBrowsable) viewModel.selectDestination(Destination.SERIES)
                                viewModel.activateLibraryItem(item, recentLocation, recentlyAdded = true)
                            }
                            HomeShelfKind.LIBRARY -> { item ->
                                viewModel.activateLibraryItem(item, shelf.location)
                            }
                        }
                        MediaShelf(
                            title = shelf.title,
                            items = shelf.items,
                            viewModel = viewModel,
                            onMore = { viewModel.openLibrary(shelf.location) },
                            onItemClick = clickHandler,
                            onItemFocus = {
                                focusedShelfIndex = index
                                focusedHeroItem = it
                            },
                            onDestinationFocus = { focusedShelfIndex = index },
                            initialFocusRequester = shelfFocusRequesters.getOrNull(index),
                            onVerticalMove = { step -> moveToShelf(index, step) },
                            fixedFocusIndicator = true,
                        )
                    }
                }

                Box(
                    fixedFocusModifier.border(
                        if (showFixedFocus) 4.dp else 1.dp,
                        if (showFixedFocus) TaterColors.OrangeBright else Color.Transparent,
                        focusShape,
                    )
                )
            }
        }
    }

    LaunchedEffect(homeShelves) {
        if (focusedHeroItem == null) {
            focusedHeroItem = homeShelves.firstOrNull()?.items?.firstOrNull()
        }
    }
    LaunchedEffect(state.selectedMedia?.id) {
        if (state.selectedMedia != null) {
            detailWasOpen = true
        } else if (detailWasOpen) {
            detailWasOpen = false
            restoringDetailFocus = true
            val returnIndex = focusedShelfIndex.coerceIn(0, (homeShelves.size - 1).coerceAtLeast(0))
            val returnRequester = shelfFocusRequesters.getOrNull(returnIndex)
            if (returnRequester != null) {
                // Wait for the detail overlay to leave the focus tree, then
                // return to the shelf's stationary target. MediaShelf keeps
                // its selected card index, so the exact card remains active.
                withFrameNanos { }
                shelfListState.scrollToItem(returnIndex)
                withFrameNanos { }
                returnRequester.requestFocus()
                // Android TV performs its own bring-into-view after focus is
                // granted. Snap the shelf back once that pass has completed
                // so its card and the stationary frame remain aligned.
                withFrameNanos { }
                shelfListState.scrollToItem(returnIndex)
                delay(120)
                shelfListState.scrollToItem(returnIndex)
            }
            restoringDetailFocus = false
        }
    }
    LaunchedEffect(Unit) {
        viewModel.refreshLibraryRows()
        while (true) {
            delay(60_000)
            homeClock = System.currentTimeMillis()
        }
    }
    RestoreInitialFocus(
        requester = shelfFocusRequesters.getOrNull(focusedShelfIndex) ?: initialFocus,
        focusKey = "cinematic-home:${homeShelves.firstOrNull()?.id}:${homeShelves.size}:$focusedShelfIndex",
        enabled = state.selectedMedia == null && !restoringDetailFocus,
    )
}

private enum class HomeShelfKind {
    CONTINUE_WATCHING,
    RECENTLY_ADDED,
    LIBRARY,
}

private data class HomeShelfRow(
    val id: String,
    val title: String,
    val items: List<MediaItem>,
    val location: LibraryLocation,
    val kind: HomeShelfKind,
)

@Composable
private fun CinematicHomeHero(item: MediaItem?, clock: Long) {
    Column(
        Modifier.fillMaxWidth().height(405.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.Start,
    ) {
        if (item == null) {
            Text(
                homeEyebrow(clock),
                color = TaterColors.OrangeBright,
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 2.4.sp,
            )
            Spacer(Modifier.height(16.dp))
            Text(
                homeMessage(clock),
                color = Color.White,
                fontSize = 56.sp,
                fontWeight = FontWeight.Bold,
                lineHeight = 62.sp,
                maxLines = 2,
                modifier = Modifier.width(800.dp),
            )
            return@Column
        }

        Text(
            item.title,
            color = Color.White,
            fontSize = 60.sp,
            fontWeight = FontWeight.Bold,
            lineHeight = 66.sp,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.width(850.dp),
        )
        val metadata = listOfNotNull(
            item.date?.takeIf(String::isNotBlank),
        ).joinToString("  •  ")
        if (metadata.isNotBlank()) {
            Spacer(Modifier.height(10.dp))
            Text(metadata, color = Color.White.copy(alpha = .80f), fontSize = 21.sp, fontWeight = FontWeight.SemiBold)
        }
        item.summary?.takeIf(String::isNotBlank)?.let { summary ->
            Spacer(Modifier.height(14.dp))
            Text(
                summary,
                color = Color.White.copy(alpha = .82f),
                fontSize = 21.sp,
                lineHeight = 29.sp,
                maxLines = 3,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.width(780.dp),
            )
        }
        if (item.progressPercent > .5 || item.viewOffsetMs > 0) {
            Spacer(Modifier.height(18.dp))
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                CinematicProgressBar(item.progressPercent.toFloat(), Modifier.width(390.dp))
                Text(progressLabel(item), color = Color.White.copy(alpha = .72f), fontSize = 17.sp)
            }
        }
        val chips = cinematicMediaChips(item)
        if (chips.isNotEmpty()) {
            Spacer(Modifier.height(18.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                chips.forEach { InfoChip(it) }
            }
        }
    }
}

@Composable
internal fun InfoChip(value: String) {
    Text(
        value,
        color = Color.White.copy(alpha = .90f),
        fontSize = 14.sp,
        fontWeight = FontWeight.Bold,
        modifier = Modifier
            .background(Color.Black.copy(alpha = .38f), RoundedCornerShape(6.dp))
            .border(1.dp, Color.White.copy(alpha = .34f), RoundedCornerShape(6.dp))
            .padding(horizontal = 12.dp, vertical = 6.dp),
    )
}

@Composable
private fun CinematicProgressBar(progress: Float, modifier: Modifier = Modifier) {
    Box(modifier.height(7.dp).background(Color.White.copy(alpha = .22f), CircleShape)) {
        Box(
            Modifier
                .fillMaxWidth((progress / 100f).coerceIn(0f, 1f))
                .height(7.dp)
                .background(TaterColors.Orange, CircleShape)
        )
    }
}

private fun progressLabel(item: MediaItem): String {
    val remainingMs = (item.durationMs - item.viewOffsetMs).coerceAtLeast(0)
    if (item.durationMs > 0 && remainingMs > 0) {
        val minutes = remainingMs / 60_000
        val hours = minutes / 60
        val remainder = minutes % 60
        return if (hours > 0) "${hours}h ${remainder}m remaining" else "${remainder}m remaining"
    }
    return "${item.progressPercent.toInt().coerceIn(1, 100)}% watched"
}

@Composable
private fun LegacyHomeScreen(viewModel: PlayerViewModel) {
    val state = viewModel.state
    val home = state.home
    if (home == null) {
        ServerBootstrapScreen(
            busy = state.isRefreshing,
            onRetry = { viewModel.refreshHome(showError = true) },
            onDisconnect = viewModel::disconnect,
        )
        return
    }
    val initialFocus = remember { FocusRequester() }
    var homeClock by remember { mutableLongStateOf(System.currentTimeMillis()) }
    val liveItems = state.liveGuide?.let { guide ->
        val elapsed = guide.elapsedSeconds(homeClock)
        guide.channels.map { channel ->
            val programs = channel.displayedPrograms(elapsed)
            val current = programs.firstOrNull()
            val next = programs.drop(1).firstOrNull()
            val artwork = current?.let(viewModel::guideArtworkUrl)
            channel.playbackItem().copy(
                title = current?.title ?: channel.title,
                subtitle = next?.let { "Up next: ${it.title}" }
                    ?: if (channel.number.isBlank()) "Live on Tater Tube" else "Channel ${channel.number}",
                summary = current?.summary ?: channel.playbackItem().summary,
                category = current?.category,
                categoryId = current?.categoryId,
                sourceIndex = current?.sourceIndex ?: 0,
                path = current?.path,
                poster = artwork ?: current?.poster ?: channel.logoUrl,
                backdrop = artwork ?: current?.backdrop,
                seriesPoster = current?.seriesPoster,
                seasonPoster = current?.seasonPoster,
                episodeStill = current?.episodeStill,
                progressPercent = current?.progress(elapsed)?.times(100.0) ?: 0.0,
            )
        }
    }?.takeIf { it.isNotEmpty() } ?: home.liveChannels
    val continueLocation = state.libraryRows
        .firstOrNull { it.entry.type.equals("continue", true) }
        ?.entry
        ?.let(LibraryLocation::fromEntry)
        ?: LibraryLocation("", "Continue Watching", continueWatching = true)
    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(start = 78.dp, end = 78.dp, top = 42.dp, bottom = 110.dp),
        verticalArrangement = Arrangement.spacedBy(54.dp),
    ) {
        item { LegacyHomeHero(home, homeClock, viewModel, initialFocus) }
        if (home.continueWatching.isNotEmpty()) {
            item {
                MediaShelf(
                    title = "Continue Watching",
                    items = home.continueWatching,
                    viewModel = viewModel,
                    onMore = {
                        viewModel.selectDestination(Destination.MOVIES)
                        viewModel.openLibrary(continueLocation)
                    },
                )
            }
        }
        if (liveItems.isNotEmpty()) {
            item {
                MediaShelf(
                    title = "Live on Tater Tube",
                    items = liveItems,
                    viewModel = viewModel,
                    onMore = { viewModel.selectDestination(Destination.LIVE_TV) },
                    onItemClick = { viewModel.play(it, resume = false) },
                )
            }
        }
        if (home.recentlyAdded.isNotEmpty()) {
            item {
                val recentLocation = LibraryLocation("local-discover:recent", "Recently Added")
                MediaShelf(
                    title = "Recently Added",
                    items = home.recentlyAdded,
                    viewModel = viewModel,
                    onMore = {
                        viewModel.selectDestination(Destination.MOVIES)
                        viewModel.openLibrary(recentLocation)
                    },
                    onItemClick = { item -> viewModel.activateLibraryItem(item, recentLocation, recentlyAdded = true) },
                )
            }
        }
    }
    LaunchedEffect(home.capabilities.tubeTV) {
        if (home.capabilities.tubeTV) {
            viewModel.refreshLiveGuide(minimumIntervalMs = 55_000L)
        }
        while (true) {
            delay(60_000)
            homeClock = System.currentTimeMillis()
            if (home.capabilities.tubeTV) {
                viewModel.refreshLiveGuide(minimumIntervalMs = 55_000L)
            }
        }
    }
    RestoreInitialFocus(
        requester = initialFocus,
        focusKey = "home:${home.capabilities.tubeTV}",
        enabled = !state.menuVisible && state.selectedMedia == null,
    )
}

@Composable
private fun LegacyHomeHero(
    home: PlayerHome,
    clock: Long,
    viewModel: PlayerViewModel,
    initialFocus: FocusRequester,
) {
    GlassSurface(Modifier.fillMaxWidth().height(320.dp), cornerRadius = 36.dp) {
        Row(
            Modifier.fillMaxSize().padding(horizontal = 55.dp, vertical = 35.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(54.dp),
        ) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(18.dp)) {
                Text(
                    homeEyebrow(clock),
                    color = TaterColors.OrangeBright,
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 2.5.sp,
                )
                Text(
                    homeMessage(clock),
                    color = Color.White,
                    fontSize = 52.sp,
                    fontWeight = FontWeight.Bold,
                    lineHeight = 60.sp,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    if (home.capabilities.tubeTV) {
                        TaterButton(
                            "Watch Live",
                            { viewModel.selectDestination(Destination.LIVE_TV) },
                            Modifier.focusRequester(initialFocus),
                        )
                    }
                    TaterButton(
                        "Browse Library",
                        { viewModel.selectDestination(Destination.MOVIES) },
                        if (home.capabilities.tubeTV) Modifier else Modifier.focusRequester(initialFocus),
                    )
                    if (home.capabilities.newznab) {
                        TaterButton("Discover", { viewModel.selectDestination(Destination.DISCOVER) })
                    }
                    if (home.capabilities.taterLink) {
                        TaterButton("Tater Picks", { viewModel.selectDestination(Destination.TATER_PICKS) })
                    }
                }
            }
        }
    }
}

private fun homeEyebrow(clock: Long): String {
    val calendar = Calendar.getInstance().apply { timeInMillis = clock }
    val weekday = SimpleDateFormat("EEEE", Locale.getDefault()).format(Date(clock)).uppercase()
    val timeOfDay = when (calendar.get(Calendar.HOUR_OF_DAY)) {
        in 5..11 -> "MORNING"
        in 12..16 -> "AFTERNOON"
        in 17..21 -> "EVENING"
        else -> "LATE NIGHT"
    }
    return "$weekday $timeOfDay"
}

private fun homeMessage(clock: Long): String {
    val calendar = Calendar.getInstance().apply { timeInMillis = clock }
    val messages = when (calendar.get(Calendar.HOUR_OF_DAY)) {
        in 5..11 -> listOf(
            "Start the day with something good.",
            "Your morning watch is ready.",
            "Ease into something worth watching.",
        )
        in 12..16 -> listOf(
            "Take a break with something good.",
            "There’s always time for one more.",
            "Your afternoon watch is ready.",
        )
        in 17..21 -> listOf(
            "Settle in and press play.",
            "Your next watch starts here.",
            "Everything good is right where you left it.",
        )
        else -> listOf(
            "One more before calling it a night?",
            "Your late-night watch is ready.",
            "Everything good is still right where you left it.",
        )
    }
    return messages[calendar.get(Calendar.DAY_OF_YEAR) % messages.size]
}

@Composable
private fun MediaShelf(
    title: String,
    items: List<MediaItem>,
    viewModel: PlayerViewModel,
    onMore: (() -> Unit)? = null,
    onItemClick: ((MediaItem) -> Unit)? = null,
    onItemFocus: ((MediaItem) -> Unit)? = null,
    onDestinationFocus: (() -> Unit)? = null,
    initialFocusRequester: FocusRequester? = null,
    onVerticalMove: ((Int) -> Boolean)? = null,
    fixedFocusIndicator: Boolean = false,
) {
    val rowState = rememberLazyListState()
    val coroutineScope = rememberCoroutineScope()
    val selectionKey = items.map(MediaItem::id) to (onMore != null)
    var selectedIndex by remember(title) { mutableIntStateOf(0) }
    var selectionFocused by remember { mutableStateOf(false) }
    var scrollJob by remember { mutableStateOf<Job?>(null) }
    val selectionCount = items.size + if (onMore == null) 0 else 1
    val selectedItem = items.getOrNull(selectedIndex)
    val destinationSelected = onMore != null && selectedIndex == items.size

    fun announceSelection() {
        if (selectedItem != null) onItemFocus?.invoke(selectedItem)
        else if (destinationSelected) onDestinationFocus?.invoke()
    }

    fun moveSelection(step: Int) {
        val next = (selectedIndex + step).coerceIn(0, (selectionCount - 1).coerceAtLeast(0))
        if (next == selectedIndex) return
        selectedIndex = next
        val nextItem = items.getOrNull(next)
        if (nextItem != null) onItemFocus?.invoke(nextItem) else onDestinationFocus?.invoke()
        scrollJob?.cancel()
        scrollJob = coroutineScope.launch { rowState.animateScrollToItem(next) }
    }

    fun activateSelection() {
        if (selectedItem != null) {
            onItemClick?.invoke(selectedItem) ?: viewModel.openDetails(selectedItem)
        } else if (destinationSelected) {
            onMore.invoke()
        }
    }

    Column {
        SectionHeading(title)
        BoxWithConstraints(Modifier.fillMaxWidth().height(222.dp)) {
            val trailingSpace = (maxWidth - 340.dp - 28.dp).coerceAtLeast(0.dp)
            val shape = RoundedCornerShape(22.dp)

            // Keep the soft focus glow beneath the artwork. The transparent
            // focus target and its crisp outline are drawn after the rail.
            Box(
                Modifier
                    .padding(start = 8.dp, top = 10.dp)
                    .width(340.dp)
                    .height(202.dp)
                    .graphicsLayer {
                        val scale = if (selectionFocused) 1.045f else 1f
                        scaleX = scale
                        scaleY = scale
                    }
                    .taterFocusGlow(selectionFocused && !fixedFocusIndicator, shape)
            )

            LazyRow(
                state = rowState,
                userScrollEnabled = false,
                horizontalArrangement = Arrangement.spacedBy(28.dp),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 8.dp, vertical = 10.dp),
            ) {
                itemsIndexed(items, key = { _, item -> item.id }) { _, item ->
                    MediaCard(
                        item = item,
                        artworkUrl = viewModel.wideArtworkUrl(item),
                        token = viewModel.token,
                        onClick = {},
                        modifier = Modifier.focusProperties { canFocus = false },
                    )
                }
                if (onMore != null) {
                    item(key = "home-shelf-destination-$title") {
                        ShelfDestinationCard(
                            text = if (title == "Live on Tater Tube") "Open Guide" else "See All",
                            onClick = {},
                            focusEnabled = false,
                        )
                    }
                }
                item(key = "home-shelf-trailing-space-$title") {
                    Spacer(Modifier.width(trailingSpace).height(202.dp))
                }
            }

            Box(
                Modifier
                    .padding(start = 8.dp, top = 10.dp)
                    .width(340.dp)
                    .height(202.dp)
                    .then(
                        if (initialFocusRequester != null) Modifier.focusRequester(initialFocusRequester)
                        else Modifier
                    )
                    .onPreviewKeyEvent { event ->
                        val native = event.nativeKeyEvent
                        if (native.action != KeyEvent.ACTION_DOWN) return@onPreviewKeyEvent false
                        when (native.keyCode) {
                            KeyEvent.KEYCODE_DPAD_LEFT -> {
                                moveSelection(-1)
                                true
                            }
                            KeyEvent.KEYCODE_DPAD_RIGHT -> {
                                moveSelection(1)
                                true
                            }
                            KeyEvent.KEYCODE_DPAD_UP -> onVerticalMove?.invoke(-1) ?: false
                            KeyEvent.KEYCODE_DPAD_DOWN -> onVerticalMove?.invoke(1) ?: false
                            else -> false
                        }
                    }
                    .onFocusChanged {
                        selectionFocused = it.isFocused
                        if (it.isFocused) announceSelection()
                    }
                    .clickable(onClick = ::activateSelection)
                    .graphicsLayer {
                        val scale = if (selectionFocused) 1.045f else 1f
                        scaleX = scale
                        scaleY = scale
                    }
                    .border(
                        if (selectionFocused && !fixedFocusIndicator) 4.dp else 1.dp,
                        if (selectionFocused && !fixedFocusIndicator) TaterColors.OrangeBright else Color.Transparent,
                        shape,
                    )
            )
        }
    }

    LaunchedEffect(selectionKey, selectionCount) {
        if (selectionCount == 0) return@LaunchedEffect
        val validIndex = selectedIndex.coerceIn(0, selectionCount - 1)
        if (validIndex != selectedIndex) {
            selectedIndex = validIndex
            rowState.scrollToItem(validIndex)
            if (selectionFocused) {
                items.getOrNull(validIndex)?.let { onItemFocus?.invoke(it) }
                    ?: onDestinationFocus?.invoke()
            }
        }
    }
}

@Composable
private fun ShelfDestinationCard(
    text: String,
    onClick: () -> Unit,
    onFocus: (() -> Unit)? = null,
    focusEnabled: Boolean = true,
) {
    var focused by remember { mutableStateOf(false) }
    val scale by animateFloatAsState(if (focused) 1.025f else 1f, label = "destination-scale")
    val shape = RoundedCornerShape(22.dp)
    Column(
        Modifier
            .width(340.dp)
            .height(202.dp)
            .focusProperties { canFocus = focusEnabled }
            .onFocusChanged {
                focused = it.isFocused
                if (it.isFocused) onFocus?.invoke()
            }
            .clickable(enabled = focusEnabled, onClick = onClick)
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
            }
            .taterFocusGlow(focused, shape)
            .background(TaterColors.Glass, shape)
            .border(if (focused) 4.dp else 1.dp, if (focused) TaterColors.OrangeBright else Color.White.copy(alpha = .1f), shape),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text("→", color = TaterColors.OrangeBright, fontSize = 54.sp, fontWeight = FontWeight.Bold)
        Text(text, color = Color.White, fontSize = 23.sp, fontWeight = FontWeight.Bold)
    }
}

/*
 * The stationary focus surface above deliberately owns all horizontal input.
 * The row cards stay visual-only so Compose never advances focus across two
 * cards before applying its default TV pivot behavior.
 */

@Composable
private fun LibraryLanding(viewModel: PlayerViewModel) {
    val home = viewModel.state.home ?: return
    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(58.dp, 48.dp, 58.dp, 70.dp),
        verticalArrangement = Arrangement.spacedBy(34.dp),
    ) {
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                TaterButton("All Movies", {})
                TaterButton("All TV Shows", {})
                if (home.capabilities.newznab) TaterButton("Discover", { viewModel.selectDestination(Destination.DISCOVER) })
                if (home.capabilities.taterLink) TaterButton("Tater Picks", { viewModel.selectDestination(Destination.TATER_PICKS) })
            }
        }
        if (home.continueWatching.isNotEmpty()) item { MediaShelf("Continue Watching", home.continueWatching, viewModel) }
        if (home.recentlyAdded.isNotEmpty()) item { MediaShelf("Recently Added", home.recentlyAdded, viewModel) }
    }
}

@Composable
private fun SimpleDestination(
    title: String,
    message: String,
    items: List<MediaItem>,
    viewModel: PlayerViewModel,
) {
    Column(
        Modifier.fillMaxSize().padding(horizontal = 58.dp, vertical = 48.dp),
        verticalArrangement = Arrangement.spacedBy(28.dp),
    ) {
        Text(title, color = Color.White, fontSize = 36.sp, fontWeight = FontWeight.Bold)
        GlassSurface(Modifier.fillMaxWidth()) {
            Text(message, color = TaterColors.SecondaryText, fontSize = 20.sp, modifier = Modifier.padding(26.dp))
        }
        if (items.isNotEmpty()) MediaShelf(title, items, viewModel)
    }
}

@Composable
private fun SettingsScreen(viewModel: PlayerViewModel) {
    val state = viewModel.state
    val initialFocus = remember { FocusRequester() }
    Column(
        Modifier.fillMaxSize().padding(start = 58.dp, end = 58.dp, top = 92.dp, bottom = 48.dp),
        verticalArrangement = Arrangement.spacedBy(22.dp),
    ) {
        Text("Settings", color = Color.White, fontSize = 36.sp, fontWeight = FontWeight.Bold)
        GlassSurface(Modifier.width(620.dp)) {
            Column(Modifier.padding(30.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
                Text(
                    if (viewModel.state.isDemo) "Demo mode" else "Connected to ${viewModel.state.home?.serverName ?: "Tater Tube Server"}",
                    color = Color.White,
                    fontSize = 21.sp,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    "Display, decoder, HDR, and audio capabilities are reported in the background when the app connects.",
                    color = TaterColors.SecondaryText,
                    fontSize = 17.sp,
                    lineHeight = 25.sp,
                )
                TaterButton("Disconnect", viewModel::disconnect, Modifier.focusRequester(initialFocus))
            }
        }
    }
    RestoreInitialFocus(
        requester = initialFocus,
        focusKey = "settings",
        enabled = !state.menuVisible && state.selectedMedia == null,
    )
}

@Composable
private fun SideMenu(viewModel: PlayerViewModel) {
    val state = viewModel.state
    val home = state.home
    val destinations = buildList {
        add(Destination.HOME)
        if (home?.capabilities?.tubeTV == true) add(Destination.LIVE_TV)
        add(Destination.MOVIES)
        add(Destination.SERIES)
        if (home?.capabilities?.newznab == true) add(Destination.DISCOVER)
        if (home?.capabilities?.taterLink == true) add(Destination.TATER_PICKS)
        add(Destination.SETTINGS)
    }
    val firstFocus = remember { FocusRequester() }

    GlassSurface(
        Modifier
            .fillMaxHeight()
            .width(390.dp)
            .padding(start = 24.dp, top = 24.dp, bottom = 24.dp),
        cornerRadius = 30.dp,
    ) {
        Column(Modifier.fillMaxSize().padding(24.dp)) {
            Image(
                painter = painterResource(R.drawable.tater_tube_logo),
                contentDescription = "Tater Tube",
                contentScale = ContentScale.Fit,
                modifier = Modifier.fillMaxWidth().height(140.dp),
            )
            Spacer(Modifier.height(12.dp))
            LazyColumn(
                Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                itemsIndexed(destinations) { index, destination ->
                    MenuItem(
                        destination = destination,
                        selected = state.destination == destination,
                        onClick = { viewModel.selectDestination(destination) },
                        modifier = if (index == 0) Modifier.focusRequester(firstFocus) else Modifier,
                    )
                }
            }
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(11.dp)) {
                Box(
                    Modifier
                        .size(11.dp)
                        .clip(CircleShape)
                        .background(if (state.isDemo) Color(0xFFFFC857) else TaterColors.Success)
                )
                Column {
                    Text(if (state.isDemo) "DEMO MODE" else "SERVER ONLINE", color = Color.White, fontSize = 13.sp, fontWeight = FontWeight.Bold)
                    if (!state.isDemo) Text(home?.serverName.orEmpty(), color = TaterColors.SecondaryText, fontSize = 13.sp)
                }
            }
        }
    }
    LaunchedEffect(Unit) { firstFocus.requestFocus() }
}

@Composable
private fun MenuItem(
    destination: Destination,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var focused by remember { mutableStateOf(false) }
    val borderColor by animateColorAsState(
        if (focused) TaterColors.OrangeBright
        else if (selected) TaterColors.Orange.copy(alpha = 0.46f)
        else Color.Transparent,
        label = "menu-border",
    )
    val scale by animateFloatAsState(if (focused) 1.025f else 1f, label = "menu-scale")
    val shape = RoundedCornerShape(16.dp)
    Row(
        modifier
            .fillMaxWidth()
            .onFocusChanged { focused = it.isFocused }
            .clickable(onClick = onClick)
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
            }
            .taterFocusGlow(focused, shape, 15.dp)
            .background(
                if (focused) Color.Black.copy(alpha = 0.92f)
                else if (selected) TaterColors.Orange.copy(alpha = 0.16f)
                else Color.Transparent,
                shape,
            )
            .border(if (focused) 4.dp else if (selected) 1.dp else 0.dp, borderColor, shape)
            .padding(horizontal = 17.dp, vertical = 13.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text(destination.glyph, color = TaterColors.OrangeBright, fontSize = 22.sp, modifier = Modifier.width(28.dp))
        Text(destination.label, color = Color.White, fontSize = 19.sp, fontWeight = FontWeight.Bold)
    }
}

@Composable
private fun MediaDetailOverlay(item: MediaItem, viewModel: PlayerViewModel) {
    val playFocus = remember { FocusRequester() }
    val hasProgress = item.viewOffsetMs > 0 || item.progressPercent > .5
    val panelShape = RoundedCornerShape(34.dp)

    Box(
        Modifier.fillMaxSize().background(Color.Black.copy(alpha = .74f)),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            Modifier
                .width(1420.dp)
                .height(720.dp)
                .clip(panelShape)
                .background(Color.Black.copy(alpha = .88f))
                .border(2.dp, TaterColors.Orange.copy(alpha = .78f), panelShape),
        ) {
            TaterArtwork(
                item = item,
                artworkUrl = viewModel.wideArtworkUrl(item),
                token = viewModel.token,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop,
                backgroundColor = Color.Black,
            )
            Box(
                Modifier
                    .fillMaxSize()
                    .background(
                        Brush.horizontalGradient(
                            listOf(
                                Color.Black.copy(alpha = .98f),
                                Color.Black.copy(alpha = .88f),
                                Color.Black.copy(alpha = .20f),
                            )
                        )
                    )
                    .background(
                        Brush.verticalGradient(
                            listOf(Color.Transparent, Color.Black.copy(alpha = .12f), Color.Black.copy(alpha = .94f))
                        )
                    )
            )

            Column(
                Modifier.fillMaxHeight().width(1320.dp).padding(start = 70.dp, top = 58.dp, end = 44.dp, bottom = 66.dp),
                verticalArrangement = Arrangement.spacedBy(15.dp),
            ) {
                Text(
                    item.title,
                    color = Color.White,
                    fontSize = 52.sp,
                    lineHeight = 58.sp,
                    fontWeight = FontWeight.Bold,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                val metadata = listOfNotNull(
                    item.date?.takeIf(String::isNotBlank),
                    item.communityRating?.takeIf { it > 0 }?.let { "★ %.1f".format(it) },
                ).joinToString("  •  ")
                if (metadata.isNotBlank()) {
                    Text(metadata, color = Color.White.copy(alpha = .82f), fontSize = 20.sp, fontWeight = FontWeight.SemiBold)
                }
                item.tagline?.takeIf(String::isNotBlank)?.let {
                    Text(it, color = Color.White.copy(alpha = .86f), fontSize = 20.sp, fontWeight = FontWeight.SemiBold)
                }
                Text(
                    item.summary ?: "Ready to play from your Tater Tube Server.",
                    color = Color.White.copy(alpha = .80f),
                    fontSize = 20.sp,
                    lineHeight = 28.sp,
                    maxLines = 4,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.width(760.dp),
                )

                val chips = cinematicMediaChips(item)
                if (chips.isNotEmpty()) {
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        chips.forEach { InfoChip(it) }
                    }
                }

                Spacer(Modifier.weight(1f))

                if (hasProgress) {
                    Text(
                        "WATCH PROGRESS",
                        color = Color.White.copy(alpha = .86f),
                        fontSize = 17.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 2.8.sp,
                    )
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(18.dp)) {
                        CinematicProgressBar(item.progressPercent.toFloat(), Modifier.width(650.dp))
                        Text(
                            detailProgressLabel(item),
                            color = Color.White.copy(alpha = .72f),
                            fontSize = 17.sp,
                            maxLines = 1,
                        )
                    }

                    Row(horizontalArrangement = Arrangement.spacedBy(18.dp)) {
                        DetailActionButton(
                            text = "▶  RESUME",
                            onClick = { viewModel.play(item, resume = true) },
                            modifier = Modifier.focusRequester(playFocus).width(300.dp),
                            prominent = true,
                            enabled = !viewModel.state.isPreparingPlayback,
                        )
                        DetailActionButton(
                            text = "↻  START OVER",
                            onClick = { viewModel.play(item, resume = false) },
                            modifier = Modifier.width(320.dp),
                            enabled = !viewModel.state.isPreparingPlayback,
                        )
                        DetailActionButton(
                            text = "CLEAR PROGRESS",
                            onClick = { viewModel.clearProgress(item) },
                            modifier = Modifier.width(300.dp),
                            enabled = !viewModel.state.isPreparingPlayback,
                        )
                    }
                } else {
                    UnwatchedSpotlight(
                        item = item,
                        playFocus = playFocus,
                        enabled = !viewModel.state.isPreparingPlayback,
                        onPlay = { viewModel.play(item, resume = false) },
                    )
                }
            }
        }
    }
    LaunchedEffect(item.id) {
        delay(120)
        playFocus.requestFocus()
    }
}

internal fun cinematicMediaChips(item: MediaItem): List<String> {
    val mediaType = when ((item.mediaType ?: item.type).orEmpty().lowercase()) {
        "movie", "film" -> "MOVIE"
        "show", "tvshow", "tv_show", "series" -> "SERIES"
        "episode" -> "EPISODE"
        "season" -> "SEASON"
        "" -> null
        else -> (item.mediaType ?: item.type)?.uppercase()
    }
    val resolution = when {
        item.videoWidth >= 3_800 || item.videoHeight >= 2_000 -> "4K"
        item.videoWidth >= 2_500 || item.videoHeight >= 1_400 -> "1440P"
        item.videoWidth >= 1_900 || item.videoHeight >= 1_000 -> "1080P"
        item.videoWidth >= 1_250 || item.videoHeight >= 700 -> "720P"
        item.videoHeight > 0 -> "${item.videoHeight}P"
        else -> null
    }
    val videoRange = when (item.videoRange.orEmpty().lowercase().replace('-', '_')) {
        "dolby_vision", "dolbyvision", "dv" -> "DOLBY VISION"
        "hdr10plus", "hdr10_plus", "hdr10+" -> "HDR10+"
        "hdr10", "hdr" -> "HDR10"
        "hlg" -> "HLG"
        else -> null
    }
    val videoCodec = when (item.videoCodec.orEmpty().lowercase()) {
        "hevc", "h265", "h.265" -> "HEVC"
        "h264", "avc", "h.264" -> "H.264"
        "av1" -> "AV1"
        "vp9" -> "VP9"
        "" -> null
        else -> item.videoCodec?.uppercase()
    }
    val audioProfile = item.audioProfile.orEmpty().lowercase()
    val audioFormat = if (audioProfile.contains("atmos") || audioProfile.contains("joc")) {
        "ATMOS"
    } else when (item.audioCodec.orEmpty().lowercase()) {
        "truehd" -> "TRUEHD"
        "eac3", "e-ac-3" -> "DOLBY DIGITAL+"
        "ac3", "ac-3" -> "DOLBY DIGITAL"
        "dts_hd", "dts-hd" -> "DTS-HD"
        "dts" -> "DTS"
        "aac" -> "AAC"
        "flac" -> "FLAC"
        "" -> null
        else -> item.audioCodec?.uppercase()
    }
    val layout = item.audioChannelLayout.orEmpty().lowercase()
    val audioChannels = when {
        item.audioChannels >= 8 -> "7.1"
        item.audioChannels >= 6 -> "5.1"
        item.audioChannels >= 2 -> "STEREO"
        item.audioChannels == 1 -> "MONO"
        layout.contains("7.1") -> "7.1"
        layout.contains("5.1") -> "5.1"
        layout.contains("stereo") -> "STEREO"
        layout.contains("mono") -> "MONO"
        else -> null
    }

    return listOfNotNull(
        mediaType,
        item.contentRating?.takeIf(String::isNotBlank),
        resolution,
        videoRange,
        videoCodec,
        audioFormat,
        audioChannels,
        item.durationMs.takeIf { it > 0 }?.let(::formatDetailDuration),
    ).distinctBy { it.lowercase() }
}

@Composable
private fun UnwatchedSpotlight(
    item: MediaItem,
    playFocus: FocusRequester,
    enabled: Boolean,
    onPlay: () -> Unit,
) {
    val shape = RoundedCornerShape(18.dp)
    Row(
        Modifier
            .fillMaxWidth()
            .background(Color.Black.copy(alpha = .72f), shape)
            .border(1.5.dp, Color.White.copy(alpha = .22f), shape)
            .padding(start = 22.dp, end = 16.dp, top = 15.dp, bottom = 15.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        Box(
            Modifier.size(58.dp).background(TaterColors.Orange.copy(alpha = .18f), CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Text("◷", color = TaterColors.OrangeBright, fontSize = 29.sp, fontWeight = FontWeight.Bold)
        }

        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(5.dp)) {
            Text(
                unwatchedRuntimeTitle(item),
                color = Color.White.copy(alpha = .94f),
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 2.sp,
            )
            Text(
                unwatchedTimingDetail(item),
                color = Color.White.copy(alpha = .64f),
                fontSize = 17.sp,
                fontWeight = FontWeight.Medium,
            )
        }

        DetailActionButton(
            text = if (item.isLiveChannel) "▶  WATCH LIVE" else "▶  PLAY",
            onClick = onPlay,
            modifier = Modifier.focusRequester(playFocus).width(280.dp),
            prominent = true,
            enabled = enabled,
        )
    }
}

@Composable
private fun DetailActionButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    prominent: Boolean = false,
    enabled: Boolean = true,
) {
    var focused by remember { mutableStateOf(false) }
    val shape = RoundedCornerShape(13.dp)
    val scale by animateFloatAsState(if (focused) 1.025f else 1f, label = "detail-action-scale")
    val background by animateColorAsState(
        when {
            focused -> TaterColors.OrangeBright
            prominent -> TaterColors.Orange.copy(alpha = .68f)
            else -> Color.Black.copy(alpha = .58f)
        },
        label = "detail-action-background",
    )
    val border by animateColorAsState(
        if (focused) Color.White.copy(alpha = .92f)
        else Color.White.copy(alpha = if (prominent) .42f else .62f),
        label = "detail-action-border",
    )

    Box(
        modifier
            .height(74.dp)
            .onFocusChanged { focused = it.isFocused }
            .clickable(enabled = enabled, onClick = onClick)
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
            }
            .taterFocusGlow(focused, shape, 19.dp)
            .background(if (enabled) background else Color.Black.copy(alpha = .42f), shape)
            .border(if (focused) 3.dp else 1.5.dp, border, shape),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text,
            color = if (enabled) Color.White else Color.White.copy(alpha = .42f),
            fontSize = 19.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = 1.2.sp,
            maxLines = 1,
        )
    }
}

private fun detailProgressLabel(item: MediaItem): String {
    val remaining = (item.durationMs - item.viewOffsetMs).coerceAtLeast(0)
    if (item.durationMs > 0 && remaining > 0) {
        val finish = estimatedFinishTime(remaining)
        return "${formatDetailDuration(remaining)} remaining  •  Finish around $finish"
    }
    return "${item.progressPercent.toInt().coerceIn(1, 100)}% watched"
}

private fun unwatchedRuntimeTitle(item: MediaItem): String =
    if (item.durationMs > 0) "${formatDetailDuration(item.durationMs).uppercase()} RUNTIME" else "READY TO PLAY"

private fun unwatchedTimingDetail(item: MediaItem): String =
    if (item.durationMs > 0) "Start now  •  Finish around ${estimatedFinishTime(item.durationMs)}"
    else "Starts from the beginning"

private fun formatDetailDuration(milliseconds: Long): String {
    val minutes = (milliseconds / 60_000).coerceAtLeast(0)
    val hours = minutes / 60
    val remainder = minutes % 60
    return if (hours > 0) "${hours}h ${remainder}m" else "${remainder}m"
}

private fun estimatedFinishTime(milliseconds: Long): String =
    SimpleDateFormat("h:mm a", Locale.getDefault())
        .format(Date(System.currentTimeMillis() + milliseconds.coerceAtLeast(0)))

@Composable
private fun LegacyMediaDetailOverlay(item: MediaItem, viewModel: PlayerViewModel) {
    val playFocus = remember { FocusRequester() }
    Box(
        Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.68f)),
        contentAlignment = Alignment.Center,
    ) {
        GlassSurface(Modifier.width(930.dp).height(470.dp), cornerRadius = 32.dp) {
            Row(Modifier.fillMaxSize().padding(28.dp), horizontalArrangement = Arrangement.spacedBy(30.dp)) {
                TaterArtwork(
                    item = item,
                    artworkUrl = viewModel.artworkUrl(item),
                    token = viewModel.token,
                    modifier = Modifier.width(300.dp).fillMaxHeight().clip(RoundedCornerShape(22.dp)),
                    contentScale = ContentScale.Crop,
                )
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    Text(item.title, color = Color.White, fontSize = 31.sp, fontWeight = FontWeight.Bold, maxLines = 2)
                    item.subtitle?.let { Text(it, color = TaterColors.OrangeBright, fontSize = 17.sp, fontWeight = FontWeight.SemiBold) }
                    Text(
                        item.summary ?: "Ready to play from your Tater Tube Server.",
                        color = TaterColors.SecondaryText,
                        fontSize = 17.sp,
                        lineHeight = 25.sp,
                        maxLines = 6,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f),
                    )
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        val hasProgress = item.viewOffsetMs > 0 || item.progressPercent > 0.5
                        TaterButton(
                            text = if (hasProgress) "Resume" else if (item.isLiveChannel) "Watch Live" else "Play",
                            onClick = { viewModel.play(item, resume = hasProgress) },
                            enabled = !viewModel.state.isPreparingPlayback,
                            modifier = Modifier.focusRequester(playFocus),
                        )
                        if (hasProgress) TaterButton("Start Over", { viewModel.play(item, resume = false) })
                        if (hasProgress) TaterButton("Clear", { viewModel.clearProgress(item) })
                    }
                }
            }
        }
    }
    LaunchedEffect(item.id) {
        delay(120)
        playFocus.requestFocus()
    }
}

@Composable
private fun MessageOverlay(message: String, onDismiss: () -> Unit) {
    val focus = remember { FocusRequester() }
    Box(
        Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.72f)),
        contentAlignment = Alignment.Center,
    ) {
        GlassSurface(Modifier.width(620.dp), cornerRadius = 28.dp) {
            Column(Modifier.padding(32.dp), verticalArrangement = Arrangement.spacedBy(22.dp)) {
                Text("Tater Tube Player", color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Bold)
                Text(message, color = TaterColors.SecondaryText, fontSize = 18.sp, lineHeight = 26.sp)
                TaterButton("OK", onDismiss, Modifier.focusRequester(focus).width(140.dp))
            }
        }
    }
    LaunchedEffect(message) { focus.requestFocus() }
}
