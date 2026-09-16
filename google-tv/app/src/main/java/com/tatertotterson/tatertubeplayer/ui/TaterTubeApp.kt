package com.tatertotterson.tatertubeplayer.ui

import android.view.KeyEvent
import androidx.activity.compose.BackHandler
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
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
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
import com.tatertotterson.tatertubeplayer.ui.components.MediaCard
import com.tatertotterson.tatertubeplayer.ui.components.RestoreInitialFocus
import com.tatertotterson.tatertubeplayer.ui.components.SectionHeading
import com.tatertotterson.tatertubeplayer.ui.components.TaterArtwork
import com.tatertotterson.tatertubeplayer.ui.components.TaterButton
import com.tatertotterson.tatertubeplayer.ui.theme.TaterColors
import com.tatertotterson.tatertubeplayer.ui.theme.taterFocusGlow
import kotlinx.coroutines.delay
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
                token = viewModel.token,
                liveGuide = state.liveGuide,
                onExit = viewModel::stopPlayback,
                onAudioTrackChange = viewModel::changeAudioTrack,
                onFirstFrame = viewModel::finishDiscoveryPreparation,
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
    BackHandler { viewModel.handleBack() }

    Box(
        Modifier
            .fillMaxSize()
            .onPreviewKeyEvent { event ->
                if (event.nativeKeyEvent.action == KeyEvent.ACTION_DOWN && event.nativeKeyEvent.keyCode == KeyEvent.KEYCODE_MENU) {
                    if (state.menuVisible) viewModel.hideMenu() else viewModel.showMenu()
                    true
                } else false
            }
    ) {
        when (state.destination) {
            Destination.HOME -> HomeScreen(viewModel)
            Destination.LIBRARY -> LibraryScreen(viewModel)
            Destination.LIVE_TV -> LiveGuideScreen(viewModel)
            Destination.DISCOVER -> DiscoveryScreen(viewModel)
            Destination.TATER_PICKS -> TaterPicksScreen(viewModel)
            Destination.SETTINGS -> SettingsScreen(viewModel)
        }

        if (state.menuVisible) {
            Box(
                Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.42f))
                    .clickable(onClick = viewModel::hideMenu)
            )
            SideMenu(viewModel)
        }

        state.selectedMedia?.let { item ->
            MediaDetailOverlay(item = item, viewModel = viewModel)
        }
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
        item { HomeHero(home, homeClock, viewModel, initialFocus) }
        if (home.continueWatching.isNotEmpty()) {
            item {
                MediaShelf(
                    title = "Continue Watching",
                    items = home.continueWatching,
                    viewModel = viewModel,
                    onMore = {
                        viewModel.selectDestination(Destination.LIBRARY)
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
                        viewModel.selectDestination(Destination.LIBRARY)
                        viewModel.openLibrary(recentLocation)
                    },
                    onItemClick = { item -> viewModel.activateLibraryItem(item, recentLocation, recentlyAdded = true) },
                )
            }
        }
    }
    LaunchedEffect(Unit) {
        while (true) {
            delay(60_000)
            homeClock = System.currentTimeMillis()
        }
    }
    RestoreInitialFocus(
        requester = initialFocus,
        focusKey = "home:${home.capabilities.tubeTV}",
        enabled = !state.menuVisible && state.selectedMedia == null,
    )
}

@Composable
private fun HomeHero(
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
                        { viewModel.selectDestination(Destination.LIBRARY) },
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
            Image(
                painter = painterResource(R.drawable.tater_hero_remote),
                contentDescription = null,
                contentScale = ContentScale.Fit,
                modifier = Modifier.width(300.dp).height(260.dp),
            )
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
) {
    Column {
        SectionHeading(title)
        LazyRow(
            horizontalArrangement = Arrangement.spacedBy(28.dp),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 8.dp, vertical = 10.dp),
        ) {
            items(items, key = { it.id }) { item ->
                MediaCard(
                    item = item,
                    artworkUrl = viewModel.wideArtworkUrl(item),
                    token = viewModel.token,
                    onClick = { onItemClick?.invoke(item) ?: viewModel.openDetails(item) },
                )
            }
            if (onMore != null) {
                item {
                    ShelfDestinationCard(
                        text = if (title == "Live on Tater Tube") "Open Guide" else "See All",
                        onClick = onMore,
                    )
                }
            }
        }
    }
}

@Composable
private fun ShelfDestinationCard(text: String, onClick: () -> Unit) {
    var focused by remember { mutableStateOf(false) }
    val scale by animateFloatAsState(if (focused) 1.025f else 1f, label = "destination-scale")
    val shape = RoundedCornerShape(22.dp)
    Column(
        Modifier
            .width(190.dp)
            .height(202.dp)
            .onFocusChanged { focused = it.isFocused }
            .clickable(onClick = onClick)
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
        Modifier.fillMaxSize().padding(horizontal = 58.dp, vertical = 48.dp),
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
        add(Destination.LIBRARY)
        if (home?.capabilities?.tubeTV == true) add(Destination.LIVE_TV)
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
