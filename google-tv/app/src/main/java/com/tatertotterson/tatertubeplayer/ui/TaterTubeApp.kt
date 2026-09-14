package com.tatertotterson.tatertubeplayer.ui

import android.view.KeyEvent
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
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
import com.tatertotterson.tatertubeplayer.model.LibraryEntry
import com.tatertotterson.tatertubeplayer.model.LibraryLocation
import com.tatertotterson.tatertubeplayer.model.MediaItem
import com.tatertotterson.tatertubeplayer.model.PlayerHome
import com.tatertotterson.tatertubeplayer.playback.PlaybackScreen
import com.tatertotterson.tatertubeplayer.ui.components.GlassSurface
import com.tatertotterson.tatertubeplayer.ui.components.MediaCard
import com.tatertotterson.tatertubeplayer.ui.components.SectionHeading
import com.tatertotterson.tatertubeplayer.ui.components.TaterArtwork
import com.tatertotterson.tatertubeplayer.ui.components.TaterButton
import com.tatertotterson.tatertubeplayer.ui.theme.TaterColors
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
                onExit = viewModel::stopPlayback,
                onAudioTrackChange = viewModel::changeAudioTrack,
            )
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
    val home = viewModel.state.home
    if (home == null) {
        StartingScreen()
        return
    }
    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(start = 58.dp, end = 58.dp, top = 42.dp, bottom = 70.dp),
        verticalArrangement = Arrangement.spacedBy(34.dp),
    ) {
        item { HomeHero(home, viewModel) }
        if (home.continueWatching.isNotEmpty()) {
            item {
                MediaShelf("Continue Watching", home.continueWatching, viewModel) {
                    viewModel.selectDestination(Destination.LIBRARY)
                    viewModel.openLibrary(LibraryLocation.fromEntry(LibraryEntry("continue", "Continue Watching", "continue")))
                }
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
        if (home.liveChannels.isNotEmpty()) {
            item { MediaShelf("Live on Tater Tube", home.liveChannels, viewModel) { viewModel.selectDestination(Destination.LIVE_TV) } }
        }
    }
}

@Composable
private fun HomeHero(home: PlayerHome, viewModel: PlayerViewModel) {
    GlassSurface(Modifier.fillMaxWidth().height(300.dp), cornerRadius = 30.dp) {
        Row(
            Modifier.fillMaxSize().padding(start = 42.dp, end = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                Text(
                    home.hero.eyebrow.uppercase(),
                    color = TaterColors.OrangeBright,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 1.4.sp,
                )
                Text(
                    home.hero.message,
                    color = Color.White,
                    fontSize = 34.sp,
                    fontWeight = FontWeight.Bold,
                    lineHeight = 42.sp,
                    maxLines = 3,
                    overflow = TextOverflow.Ellipsis,
                )
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    TaterButton("Browse Library", { viewModel.selectDestination(Destination.LIBRARY) })
                    if (home.capabilities.newznab) {
                        TaterButton("Discover", { viewModel.selectDestination(Destination.DISCOVER) })
                    }
                    if (home.capabilities.taterLink) {
                        TaterButton("Tater Picks", { viewModel.selectDestination(Destination.TATER_PICKS) })
                    }
                    if (home.capabilities.tubeTV) {
                        TaterButton("Watch Live", { viewModel.selectDestination(Destination.LIVE_TV) })
                    }
                }
            }
            Image(
                painter = painterResource(R.drawable.tater_hero_remote),
                contentDescription = null,
                contentScale = ContentScale.Fit,
                modifier = Modifier.width(420.dp).fillMaxHeight(),
            )
        }
    }
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
        LazyRow(horizontalArrangement = Arrangement.spacedBy(18.dp)) {
            items(items, key = { it.id }) { item ->
                MediaCard(
                    item = item,
                    artworkUrl = viewModel.artworkUrl(item),
                    token = viewModel.token,
                    onClick = { onItemClick?.invoke(item) ?: viewModel.openDetails(item) },
                )
            }
            if (onMore != null) {
                item {
                    TaterButton(
                        text = if (title == "Live on Tater Tube") "Open Guide" else "See All",
                        onClick = onMore,
                        modifier = Modifier.width(160.dp).height(146.dp),
                    )
                }
            }
        }
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
                TaterButton("Disconnect", viewModel::disconnect)
            }
        }
    }
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
    Row(
        modifier
            .fillMaxWidth()
            .onFocusChanged { focused = it.isFocused }
            .clickable(onClick = onClick)
            .background(
                if (focused) Color.Black.copy(alpha = 0.92f)
                else if (selected) TaterColors.Orange.copy(alpha = 0.16f)
                else Color.Transparent,
                RoundedCornerShape(16.dp),
            )
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
    LaunchedEffect(item.id) { playFocus.requestFocus() }
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
