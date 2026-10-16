package com.tatertotterson.tatertubeplayer.ui

import androidx.activity.compose.BackHandler
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.focusGroup
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
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
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.focusRestorer
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.tv.material3.Text
import com.tatertotterson.tatertubeplayer.model.DiscoverCategory
import com.tatertotterson.tatertubeplayer.model.LibraryLocation
import com.tatertotterson.tatertubeplayer.model.LibraryRow
import com.tatertotterson.tatertubeplayer.model.LiveChannel
import com.tatertotterson.tatertubeplayer.model.LiveGuide
import com.tatertotterson.tatertubeplayer.model.LiveProgram
import com.tatertotterson.tatertubeplayer.model.MediaItem
import com.tatertotterson.tatertubeplayer.model.RecommendationItem
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
import java.util.Date
import java.util.Locale
import kotlin.math.ceil

@Composable
fun LibraryScreen(viewModel: PlayerViewModel, rootLocation: LibraryLocation) {
    val state = viewModel.state
    val location = state.libraryStack.lastOrNull() ?: rootLocation
    val focusHistory = remember(rootLocation.cacheKey) { mutableStateMapOf<String, String>() }
    val stackSignature = state.libraryStack.joinToString("|") { it.cacheKey }
    var previousStackSignature by remember(rootLocation.cacheKey) { mutableStateOf(stackSignature) }
    var navigationFocusRevision by remember(rootLocation.cacheKey) {
        mutableIntStateOf(if (state.libraryStack.isNotEmpty()) 1 else 0)
    }

    LaunchedEffect(stackSignature) {
        if (stackSignature != previousStackSignature) {
            previousStackSignature = stackSignature
            navigationFocusRevision++
        }
    }

    LibraryCollection(
        location = location,
        viewModel = viewModel,
        focusHistory = focusHistory,
        navigationFocusRevision = navigationFocusRevision,
    )
}

@Composable
private fun LibraryOverview(viewModel: PlayerViewModel) {
    val state = viewModel.state
    val home = state.home ?: return
    val initialFocus = remember { FocusRequester() }
    val rows = state.libraryRows.filter { row ->
        val id = row.entry.id.lowercase()
        val type = row.entry.type.orEmpty().lowercase()
        row.items.isNotEmpty() && id != "local-discover:movies" && id != "local-discover:series" && type != "local"
    }
    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(start = 58.dp, end = 58.dp, top = 46.dp, bottom = 80.dp),
        verticalArrangement = Arrangement.spacedBy(34.dp),
    ) {
        item {
            GlassSurface(Modifier.fillMaxWidth(), cornerRadius = 28.dp) {
                Row(
                    Modifier.padding(22.dp),
                    horizontalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    TaterButton(
                        "All Movies",
                        { viewModel.openLibrary(LibraryLocation.AllMovies) },
                        Modifier.weight(1f).focusRequester(initialFocus),
                    )
                    TaterButton("All TV Shows", { viewModel.openLibrary(LibraryLocation.AllShows) }, Modifier.weight(1f))
                    if (home.capabilities.newznab) {
                        TaterButton("Discover", { viewModel.selectDestination(Destination.DISCOVER) }, Modifier.weight(1f))
                    }
                    if (home.capabilities.taterLink) {
                        TaterButton("Tater Picks", { viewModel.selectDestination(Destination.TATER_PICKS) }, Modifier.weight(1f))
                    }
                }
            }
        }
        items(rows, key = { it.entry.id }) { row -> LibraryShelf(row, viewModel) }
        if (rows.isEmpty()) {
            item {
                StatePanel(
                    if (state.isLibraryRefreshing) "Loading your library…" else "Your library is ready for a scan",
                    "Movies, shows, and collections from Tater Tube Server will appear here.",
                    state.isLibraryRefreshing,
                )
            }
        }
    }
    RestoreInitialFocus(
        requester = initialFocus,
        focusKey = "library-overview",
        enabled = !state.menuVisible && state.selectedMedia == null,
    )
}

@Composable
private fun LibraryShelf(row: LibraryRow, viewModel: PlayerViewModel) {
    val parent = LibraryLocation.fromEntry(row.entry)
    Column {
        SectionHeading(row.title)
        LazyRow(
            horizontalArrangement = Arrangement.spacedBy(28.dp),
            contentPadding = PaddingValues(horizontal = 8.dp, vertical = 10.dp),
        ) {
            items(row.items, key = { it.id }) { item ->
                MediaCard(
                    item = item,
                    artworkUrl = viewModel.wideArtworkUrl(item),
                    token = viewModel.token,
                    onClick = {
                        viewModel.activateLibraryItem(
                            item,
                            parent,
                            recentlyAdded = row.entry.id.equals("local-discover:recent", true),
                        )
                    },
                )
            }
            item {
                DestinationCard("See All", "→") { viewModel.openLibrary(parent) }
            }
        }
    }
}

@Composable
private fun LibraryCollection(
    location: LibraryLocation,
    viewModel: PlayerViewModel,
    focusHistory: MutableMap<String, String>,
    navigationFocusRevision: Int,
) {
    val state = viewModel.state
    val page = state.libraryPages[location.cacheKey]
    val items = page?.items.orEmpty().naturalOrder()
    val firstItemId = items.firstOrNull()?.id
    var lastFocusedItemId by remember(location.cacheKey) {
        mutableStateOf(focusHistory[location.cacheKey])
    }
    val focusTargetId = lastFocusedItemId?.takeIf { remembered -> items.any { it.id == remembered } } ?: firstItemId
    val fallbackFocus = remember(location.cacheKey) { FocusRequester() }
    val itemFocusRequesters = remember(location.cacheKey, items.map { it.id }) {
        items.associate { it.id to FocusRequester() }
    }
    val initialFocus = focusTargetId?.let(itemFocusRequesters::get) ?: fallbackFocus
    val collectionGridState = rememberLazyGridState()
    val collectionListState = rememberLazyListState()
    var detailsWereOpen by remember(location.cacheKey) { mutableStateOf(false) }
    var detailReturnItemId by remember(location.cacheKey) { mutableStateOf<String?>(null) }
    val isEpisodePage = items.isNotEmpty() && items.count { it.isEpisode } >= items.size / 2
    val isAllShowsCollection = location.categoryId == LibraryLocation.AllShows.categoryId &&
        location.sourceIndex == LibraryLocation.AllShows.sourceIndex &&
        location.path.isBlank()
    val showHero = !isAllShowsCollection &&
        location.mediaType.orEmpty().lowercase() in setOf("show", "series", "season", "tvshow")
    val isSeriesDetail = showHero && items.any {
        (it.mediaType ?: it.type).equals("season", true)
    }

    Box(Modifier.fillMaxSize()) {
        if (showHero && !location.backdrop.isNullOrBlank()) {
            TaterArtwork(
                item = MediaItem("background", location.title, backdrop = location.backdrop),
                artworkUrl = viewModel.resolveArtworkUrl(location.backdrop),
                token = viewModel.token,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop,
            )
            Box(
                Modifier
                    .fillMaxSize()
                    .background(
                        Brush.horizontalGradient(
                            listOf(Color.Black.copy(alpha = .96f), Color.Black.copy(alpha = .56f), Color.Transparent)
                        )
                    )
                    .background(
                        Brush.verticalGradient(
                            listOf(Color.Transparent, Color.Black.copy(alpha = .56f), Color.Black)
                        )
                    )
            )
        }

        Column(
            Modifier.fillMaxSize().padding(start = 58.dp, end = 58.dp, top = 84.dp, bottom = 48.dp),
            verticalArrangement = Arrangement.spacedBy(26.dp),
        ) {
            if (showHero && !isSeriesDetail) CollectionHero(location, items, viewModel)

            if (isSeriesDetail) {
                SeriesDetailCollection(
                    location = location,
                    seasons = items,
                    viewModel = viewModel,
                    navigationFocusRevision = navigationFocusRevision,
                    modifier = Modifier.weight(1f),
                )
            } else if (page == null && state.loadingLibraryKey == location.cacheKey) {
                StatePanel("Loading ${location.title}…", "Your cached collection appears immediately when available.", true)
            } else if (items.isEmpty()) {
                StatePanel("Nothing here yet", "This collection is currently empty on Tater Tube Server.")
            } else if (isEpisodePage) {
                LazyColumn(
                    modifier = Modifier.weight(1f),
                    state = collectionListState,
                    verticalArrangement = Arrangement.spacedBy(22.dp),
                    contentPadding = PaddingValues(8.dp),
                ) {
                    items(items, key = { it.id }) { item ->
                        CinematicEpisodeCard(
                            item,
                            viewModel,
                            modifier = Modifier.focusRequester(itemFocusRequesters.getValue(item.id)),
                            onFocus = { focused ->
                                if (focused && !detailsWereOpen) {
                                    lastFocusedItemId = item.id
                                    focusHistory[location.cacheKey] = item.id
                                }
                            },
                        ) { viewModel.openDetails(item) }
                    }
                }
            } else {
                LazyVerticalGrid(
                    columns = GridCells.Adaptive(248.dp),
                    modifier = Modifier.weight(1f),
                    state = collectionGridState,
                    horizontalArrangement = Arrangement.spacedBy(22.dp),
                    verticalArrangement = Arrangement.spacedBy(26.dp),
                    contentPadding = PaddingValues(horizontal = 12.dp, vertical = 18.dp),
                ) {
                    items(items, key = { it.id }) { item ->
                        PosterCard(
                            item,
                            viewModel,
                            modifier = Modifier.focusRequester(itemFocusRequesters.getValue(item.id)),
                            onFocus = { focused ->
                                if (focused && !detailsWereOpen) {
                                    lastFocusedItemId = item.id
                                    focusHistory[location.cacheKey] = item.id
                                }
                            },
                        ) {
                            viewModel.activateLibraryItem(item, location)
                        }
                    }
                }
            }
        }
    }
    RestoreInitialFocus(
        requester = initialFocus,
        focusKey = "${location.cacheKey}:$focusTargetId",
        enabled = focusTargetId != null && !isSeriesDetail && state.selectedMedia == null,
    )
    LaunchedEffect(navigationFocusRevision, focusTargetId, isSeriesDetail, state.selectedMedia?.id) {
        if (
            navigationFocusRevision <= 0 ||
            focusTargetId == null ||
            isSeriesDetail ||
            state.selectedMedia != null
        ) return@LaunchedEffect

        val returnIndex = items.indexOfFirst { it.id == focusTargetId }
        if (returnIndex < 0) return@LaunchedEffect
        delay(80)
        if (isEpisodePage) collectionListState.scrollToItem(returnIndex)
        else collectionGridState.scrollToItem(returnIndex)
        withFrameNanos { }
        itemFocusRequesters[focusTargetId]?.let { requester ->
            runCatching { requester.requestFocus() }
        }
        // Keep the restored card visible after the TV focus system performs
        // its automatic bring-into-view pass.
        withFrameNanos { }
        if (isEpisodePage) collectionListState.scrollToItem(returnIndex)
        else collectionGridState.scrollToItem(returnIndex)
    }
    LaunchedEffect(state.selectedMedia?.id) {
        if (state.selectedMedia != null) {
            detailReturnItemId = lastFocusedItemId ?: focusTargetId
            detailsWereOpen = true
        } else if (detailsWereOpen && !isSeriesDetail) {
            val returnId = detailReturnItemId
            delay(80)
            itemFocusRequesters[returnId]?.let { requester ->
                runCatching { requester.requestFocus() }
            }
            if (returnId != null) {
                lastFocusedItemId = returnId
                focusHistory[location.cacheKey] = returnId
            }
            detailReturnItemId = null
            detailsWereOpen = false
        }
    }
    LaunchedEffect(location.cacheKey) { viewModel.loadLibraryPage(location) }
}

@Composable
private fun SeriesDetailCollection(
    location: LibraryLocation,
    seasons: List<MediaItem>,
    viewModel: PlayerViewModel,
    navigationFocusRevision: Int,
    modifier: Modifier = Modifier,
) {
    val state = viewModel.state
    var selectedSeasonId by remember(location.cacheKey) { mutableStateOf<String?>(null) }
    val selectedSeason = seasons.firstOrNull { it.id == selectedSeasonId } ?: seasons.firstOrNull()
    val selectedSeasonLocation = selectedSeason?.let { LibraryLocation.fromItem(it, location) }
    val episodes = selectedSeasonLocation
        ?.let { state.libraryPages[it.cacheKey]?.items }
        .orEmpty()
        .naturalOrder()
    val firstSeasonFocus = remember(location.cacheKey) { FocusRequester() }
    val episodeFocusHistory = remember(location.cacheKey) { mutableStateMapOf<String, String>() }
    val episodeFocusKey = selectedSeasonLocation?.cacheKey
    var lastFocusedEpisodeId by remember(location.cacheKey, episodeFocusKey) {
        mutableStateOf(episodeFocusKey?.let(episodeFocusHistory::get))
    }
    val rememberedEpisodeId = lastFocusedEpisodeId?.takeIf { remembered -> episodes.any { it.id == remembered } }
    val episodeFocusTargetId = rememberedEpisodeId ?: episodes.firstOrNull()?.id
    val episodeFocusRequesters = remember(location.cacheKey, episodeFocusKey, episodes.map { it.id }) {
        episodes.associate { it.id to FocusRequester() }
    }
    var seasonNavigationFocused by remember(location.cacheKey) { mutableStateOf(false) }
    var detailsWereOpen by remember(location.cacheKey) { mutableStateOf(false) }
    var detailReturnEpisodeId by remember(location.cacheKey) { mutableStateOf<String?>(null) }

    Column(modifier, verticalArrangement = Arrangement.spacedBy(24.dp)) {
        Column(Modifier.fillMaxWidth().height(255.dp), verticalArrangement = Arrangement.Bottom) {
            Text(
                location.title,
                color = Color.White,
                fontSize = 54.sp,
                lineHeight = 60.sp,
                fontWeight = FontWeight.Bold,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            Spacer(Modifier.height(10.dp))
            val episodeCount = seasons.sumOf { maxOf(it.episodeCount, it.leafCount) }
            Text(
                "${seasons.size} ${if (seasons.size == 1) "Season" else "Seasons"}" +
                    if (episodeCount > 0) "  •  $episodeCount Episodes" else "",
                color = Color.White.copy(alpha = .80f),
                fontSize = 20.sp,
                fontWeight = FontWeight.SemiBold,
            )
            location.summary?.takeIf(String::isNotBlank)?.let { summary ->
                Spacer(Modifier.height(13.dp))
                Text(
                    summary,
                    color = Color.White.copy(alpha = .80f),
                    fontSize = 20.sp,
                    lineHeight = 27.sp,
                    maxLines = 3,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.width(820.dp),
                )
            }
            seasons.firstOrNull { !it.resumeTitle.isNullOrBlank() }?.resumeTitle?.let { upNext ->
                Spacer(Modifier.height(12.dp))
                Text("Up next: $upNext", color = TaterColors.OrangeBright, fontSize = 18.sp, fontWeight = FontWeight.SemiBold)
            }
        }

        LazyRow(
            modifier = Modifier
                .onFocusChanged { seasonNavigationFocused = it.hasFocus }
                .focusRestorer(firstSeasonFocus)
                .focusGroup(),
            horizontalArrangement = Arrangement.spacedBy(24.dp),
            contentPadding = PaddingValues(horizontal = 8.dp, vertical = 8.dp),
        ) {
            itemsIndexed(seasons, key = { _, item -> item.id }) { index, season ->
                SeasonTab(
                    title = season.title.uppercase(),
                    selected = season.id == selectedSeason?.id,
                    onClick = { selectedSeasonId = season.id },
                    modifier = if (season.id == selectedSeason?.id) Modifier.focusRequester(firstSeasonFocus) else Modifier,
                )
            }
        }

        when {
            selectedSeasonLocation == null -> {
                StatePanel("No seasons found", "This series does not have any seasons available yet.")
            }
            state.loadingLibraryKey == selectedSeasonLocation.cacheKey && episodes.isEmpty() -> {
                StatePanel("Loading ${selectedSeasonLocation.title}…", "Getting the episode list ready.", true)
            }
            episodes.isEmpty() -> {
                StatePanel("No episodes found", "This season does not have any episodes available yet.")
            }
            else -> {
                LazyColumn(
                    Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(18.dp),
                    contentPadding = PaddingValues(horizontal = 8.dp, vertical = 8.dp),
                ) {
                    items(episodes, key = { it.id }) { episode ->
                        CinematicEpisodeCard(
                            item = episode,
                            viewModel = viewModel,
                            modifier = Modifier.focusRequester(episodeFocusRequesters.getValue(episode.id)),
                            onFocus = { focused ->
                                if (focused && episodeFocusKey != null && !detailsWereOpen) {
                                    lastFocusedEpisodeId = episode.id
                                    episodeFocusHistory[episodeFocusKey] = episode.id
                                }
                            },
                        ) { viewModel.openDetails(episode) }
                    }
                }
            }
        }
    }

    LaunchedEffect(seasons.map { it.id }) {
        if (selectedSeasonId == null || seasons.none { it.id == selectedSeasonId }) {
            selectedSeasonId = seasons.firstOrNull { !it.resumeTitle.isNullOrBlank() }?.id ?: seasons.firstOrNull()?.id
        }
    }
    LaunchedEffect(selectedSeasonLocation?.cacheKey) {
        selectedSeasonLocation?.let { viewModel.loadLibraryPage(it) }
    }
    ForceFocusOnRevision(
        requester = firstSeasonFocus,
        revision = navigationFocusRevision,
        enabled = seasons.isNotEmpty() && state.selectedMedia == null,
    )
    LaunchedEffect(state.selectedMedia?.id) {
        if (state.selectedMedia != null) {
            detailReturnEpisodeId = lastFocusedEpisodeId ?: episodeFocusTargetId
            detailsWereOpen = true
        } else if (detailsWereOpen) {
            val returnId = detailReturnEpisodeId
            delay(80)
            episodeFocusRequesters[returnId]?.let { requester ->
                runCatching { requester.requestFocus() }
            }
            if (returnId != null && episodeFocusKey != null) {
                lastFocusedEpisodeId = returnId
                episodeFocusHistory[episodeFocusKey] = returnId
            }
            detailReturnEpisodeId = null
            detailsWereOpen = false
        }
    }
    BackHandler(
        enabled = seasons.isNotEmpty() && !seasonNavigationFocused && state.selectedMedia == null,
    ) {
        firstSeasonFocus.requestFocus()
    }
}

@Composable
private fun SeasonTab(
    title: String,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var focused by remember { mutableStateOf(false) }
    Column(
        modifier
            .onFocusChanged {
                focused = it.isFocused
                if (it.isFocused && !selected) onClick()
            }
            .clickable(onClick = onClick)
            .graphicsLayer {
                val scale = if (focused) 1.05f else 1f
                scaleX = scale
                scaleY = scale
            }
            .padding(horizontal = 12.dp, vertical = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(9.dp),
    ) {
        Text(
            title,
            color = when {
                focused -> TaterColors.OrangeBright
                selected -> Color.White
                else -> Color.White.copy(alpha = .72f)
            },
            fontSize = 19.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = 2.2.sp,
            maxLines = 1,
        )
        Box(
            Modifier
                .width(120.dp)
                .height(4.dp)
                .background(if (selected || focused) TaterColors.Orange else Color.Transparent, CircleShape)
        )
    }
}

@Composable
private fun CinematicEpisodeCard(
    item: MediaItem,
    viewModel: PlayerViewModel,
    modifier: Modifier = Modifier,
    onFocus: (Boolean) -> Unit = {},
    onClick: () -> Unit,
) {
    FocusCard(onClick, modifier.fillMaxWidth(), 20.dp, onFocus) {
        Row(Modifier.fillMaxWidth().padding(16.dp), horizontalArrangement = Arrangement.spacedBy(28.dp)) {
            TaterArtwork(
                item,
                viewModel.wideArtworkUrl(item),
                viewModel.token,
                Modifier.width(390.dp).height(210.dp).clip(RoundedCornerShape(18.dp)),
            )
            Column(Modifier.weight(1f).height(210.dp), verticalArrangement = Arrangement.Center) {
                Text(
                    item.subtitle?.uppercase() ?: "EPISODE",
                    color = Color.White.copy(alpha = .72f),
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 1.8.sp,
                    maxLines = 1,
                )
                Spacer(Modifier.height(8.dp))
                Text(item.title, color = Color.White, fontSize = 27.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                item.summary?.takeIf(String::isNotBlank)?.let {
                    Spacer(Modifier.height(9.dp))
                    Text(it, color = TaterColors.SecondaryText, fontSize = 17.sp, lineHeight = 23.sp, maxLines = 2, overflow = TextOverflow.Ellipsis)
                }
            }
            Column(
                Modifier.width(220.dp).height(210.dp),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.End,
            ) {
                if (item.durationMs > 0) {
                    Text(formatRuntime(item.durationMs), color = Color.White.copy(alpha = .72f), fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
                    Spacer(Modifier.height(14.dp))
                }
                when {
                    item.progressPercent >= 95 -> Text("✓  Watched", color = Color.White.copy(alpha = .76f), fontSize = 18.sp)
                    item.progressPercent > .5 || item.viewOffsetMs > 0 -> {
                        Box(Modifier.width(190.dp)) {
                            ProgressBar(item.progressPercent.toFloat())
                        }
                        Spacer(Modifier.height(8.dp))
                        Text(episodeProgressLabel(item), color = Color.White.copy(alpha = .68f), fontSize = 16.sp, maxLines = 1)
                    }
                }
            }
        }
    }
}

private fun formatRuntime(milliseconds: Long): String {
    val minutes = (milliseconds / 60_000).coerceAtLeast(0)
    val hours = minutes / 60
    val remainder = minutes % 60
    return if (hours > 0) "${hours}h ${remainder}m" else "${remainder}m"
}

private fun episodeProgressLabel(item: MediaItem): String {
    val remaining = (item.durationMs - item.viewOffsetMs).coerceAtLeast(0)
    return if (item.durationMs > 0 && remaining > 0) {
        "${formatRuntime(remaining)} remaining"
    } else {
        "${item.progressPercent.toInt().coerceIn(1, 100)}% watched"
    }
}

@Composable
private fun CollectionHero(location: LibraryLocation, items: List<MediaItem>, viewModel: PlayerViewModel) {
    val resume = items.firstOrNull { it.canPlay && it.progressPercent in 0.5..94.9 }
    GlassSurface(Modifier.fillMaxWidth().height(250.dp), cornerRadius = 30.dp) {
        Row(Modifier.fillMaxSize().padding(24.dp), horizontalArrangement = Arrangement.spacedBy(28.dp)) {
            TaterArtwork(
                item = MediaItem("hero", location.title, poster = location.poster),
                artworkUrl = location.poster?.let(viewModel::resolveArtworkUrl),
                token = viewModel.token,
                modifier = Modifier.width(150.dp).fillMaxHeight().clip(RoundedCornerShape(18.dp)),
            )
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(location.title, color = Color.White, fontSize = 32.sp, fontWeight = FontWeight.Bold, maxLines = 2)
                val seasons = items.count { (it.mediaType ?: it.type).equals("season", true) }
                val episodes = items.sumOf { maxOf(it.episodeCount, it.leafCount) }
                Text(
                    if (seasons > 0) "$seasons seasons${if (episodes > 0) "  ·  $episodes episodes" else ""}" else "${items.size} episodes",
                    color = TaterColors.OrangeBright,
                    fontSize = 17.sp,
                    fontWeight = FontWeight.Bold,
                )
                location.summary?.let {
                    Text(it, color = TaterColors.SecondaryText, fontSize = 16.sp, lineHeight = 23.sp, maxLines = 4)
                }
                resume?.let { TaterButton("Continue Episode", { viewModel.play(it, true) }) }
            }
        }
    }
}

@Composable
private fun PosterCard(
    item: MediaItem,
    viewModel: PlayerViewModel,
    modifier: Modifier = Modifier,
    onFocus: (Boolean) -> Unit = {},
    onClick: () -> Unit,
) {
    FocusCard(onClick, modifier.width(248.dp), 20.dp, onFocus) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            TaterArtwork(
                item,
                viewModel.artworkUrl(item),
                viewModel.token,
                Modifier.fillMaxWidth().height(365.dp).clip(RoundedCornerShape(18.dp)),
            )
            Text(item.title, color = Color.White, fontSize = 26.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.padding(horizontal = 14.dp))
            val count = maxOf(item.episodeCount, item.leafCount)
            Text(
                item.resumeTitle?.let { "Continue $it" } ?: if (count > 0) "$count episodes" else item.subtitle.orEmpty(),
                color = if (item.resumeTitle != null) TaterColors.OrangeBright else TaterColors.SecondaryText,
                fontSize = 20.sp,
                maxLines = 1,
                modifier = Modifier.padding(horizontal = 14.dp),
            )
            ProgressBar(item.progressPercent.toFloat())
            Spacer(Modifier.height(6.dp))
        }
    }
}

@Composable
private fun EpisodeCard(item: MediaItem, viewModel: PlayerViewModel, modifier: Modifier = Modifier, onClick: () -> Unit) {
    FocusCard(onClick, modifier.fillMaxWidth(), 22.dp) {
        Row(Modifier.padding(12.dp), horizontalArrangement = Arrangement.spacedBy(18.dp)) {
            TaterArtwork(
                item,
                viewModel.wideArtworkUrl(item),
                viewModel.token,
                Modifier.width(220.dp).height(126.dp).clip(RoundedCornerShape(16.dp)),
            )
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(7.dp)) {
                Text(item.subtitle ?: item.mediaType.orEmpty().uppercase(), color = TaterColors.OrangeBright, fontSize = 13.sp, fontWeight = FontWeight.Bold)
                Text(item.title, color = Color.White, fontSize = 20.sp, fontWeight = FontWeight.Bold, maxLines = 2)
                item.summary?.let { Text(it, color = TaterColors.SecondaryText, fontSize = 14.sp, maxLines = 2, overflow = TextOverflow.Ellipsis) }
                ProgressBar(item.progressPercent.toFloat())
            }
        }
    }
}

@Composable
fun LiveGuideScreen(viewModel: PlayerViewModel) {
    val state = viewModel.state
    val guide = state.liveGuide
    val initialFocus = remember { FocusRequester() }
    var clock by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) {
        viewModel.refreshLiveGuide()
        while (true) {
            delay(1_000)
            clock = System.currentTimeMillis()
        }
    }
    LaunchedEffect(Unit) {
        while (true) {
            delay(30_000)
            viewModel.refreshLiveGuide()
        }
    }

    if (guide == null || guide.channels.isEmpty()) {
        Box(Modifier.fillMaxSize().padding(top = 44.dp), contentAlignment = Alignment.Center) {
            StatePanel(
                if (state.isLiveGuideRefreshing) "Tuning your Tater Tube guide…" else "No channels are on the guide yet",
                "Build or enable Tube TV channels on Tater Tube Server.",
                state.isLiveGuideRefreshing,
            )
        }
        return
    }
    val elapsed = guide.elapsedSeconds(clock)
    val firstChannelId = guide.channels.firstOrNull()?.id
    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(start = 46.dp, end = 46.dp, top = 74.dp, bottom = 80.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        stickyHeader { GuideHeader() }
        items(guide.channels, key = { it.id }) { channel ->
            GuideRow(
                channel,
                guide,
                elapsed,
                viewModel,
                channelModifier = if (channel.id == firstChannelId) Modifier.focusRequester(initialFocus) else Modifier,
            )
        }
    }
    RestoreInitialFocus(
        requester = initialFocus,
        focusKey = "guide:$firstChannelId",
        enabled = firstChannelId != null && !state.menuVisible && state.selectedMedia == null,
    )
}

@Composable
private fun GuideHeader() {
    GlassSurface(Modifier.fillMaxWidth().height(54.dp), cornerRadius = 20.dp) {
        Row(Modifier.fillMaxSize().padding(horizontal = 18.dp), verticalAlignment = Alignment.CenterVertically) {
            Text("CHANNEL", Modifier.width(210.dp), color = Color.White.copy(alpha = .72f), fontSize = 14.sp, fontWeight = FontWeight.Bold)
            listOf("ON NOW", "UP NEXT", "LATER").forEach {
                Text(it, Modifier.weight(1f).padding(start = 12.dp), color = Color.White.copy(alpha = .72f), fontSize = 14.sp, fontWeight = FontWeight.Bold)
            }
        }
    }
}

@Composable
private fun GuideRow(
    channel: LiveChannel,
    guide: LiveGuide,
    elapsed: Double,
    viewModel: PlayerViewModel,
    channelModifier: Modifier = Modifier,
) {
    val programs = channel.displayedPrograms(elapsed)
    Row(Modifier.fillMaxWidth().height(180.dp), horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        ChannelCard(channel, viewModel, channelModifier.width(210.dp))
        repeat(3) { index ->
            val program = programs.getOrNull(index)
            if (program == null) GuidePlaceholder(index, Modifier.weight(1f))
            else ProgramCard(
                program,
                guide,
                elapsed,
                isCurrent = program.start <= elapsed && elapsed < program.end || (index == 0 && program.end <= program.start),
                position = index,
                viewModel = viewModel,
                channel = channel,
                modifier = Modifier.weight(1f),
            )
        }
    }
}

@Composable
private fun ChannelCard(channel: LiveChannel, viewModel: PlayerViewModel, modifier: Modifier = Modifier) {
    FocusCard({ viewModel.playChannel(channel) }, modifier.fillMaxHeight(), 20.dp) {
        Box(
            Modifier.fillMaxSize().background(
                Brush.linearGradient(listOf(Color.Black.copy(alpha = .82f), TaterColors.Orange.copy(alpha = .16f)))
            )
        ) {
            if (!channel.logoUrl.isNullOrBlank()) {
                TaterArtwork(
                    MediaItem("logo:${channel.id}", channel.title, poster = channel.logoUrl),
                    viewModel.resolveArtworkUrl(channel.logoUrl),
                    viewModel.token,
                    Modifier.fillMaxSize().padding(horizontal = 18.dp, vertical = 24.dp),
                    ContentScale.Fit,
                    backgroundColor = Color.Transparent,
                )
            } else {
                Column(Modifier.align(Alignment.Center).padding(14.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("TATER", color = TaterColors.OrangeBright, fontSize = 13.sp, fontWeight = FontWeight.Black)
                    Text(channel.logoTitle ?: channel.title, color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.Black, maxLines = 2)
                }
            }
            Text(
                if (channel.number.isBlank()) "LIVE" else "CH ${channel.number}",
                color = Color.White,
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.align(Alignment.BottomStart).padding(13.dp),
            )
        }
    }
}

@Composable
private fun ProgramCard(
    program: LiveProgram,
    guide: LiveGuide,
    elapsed: Double,
    isCurrent: Boolean,
    position: Int,
    viewModel: PlayerViewModel,
    channel: LiveChannel,
    modifier: Modifier,
) {
    FocusCard(if (isCurrent) ({ viewModel.playChannel(channel) }) else null, modifier.fillMaxHeight(), 20.dp) {
        Box(Modifier.fillMaxSize()) {
            val artwork = program.artwork
            val resolvedArtwork = viewModel.guideArtworkUrl(program)
            if (!resolvedArtwork.isNullOrBlank()) {
                TaterArtwork(
                    MediaItem("program:${program.id}", program.title, backdrop = artwork),
                    resolvedArtwork,
                    viewModel.token,
                    Modifier.fillMaxSize(),
                )
            }
            Box(Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(Color.Transparent, Color.Black.copy(alpha = .92f)))))
            Column(Modifier.align(Alignment.BottomStart).padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    if (isCurrent) "ON NOW" else guide.startTime(program)?.formatTime() ?: if (position == 1) "UP NEXT" else "LATER",
                    color = if (isCurrent) TaterColors.OrangeBright else Color.White.copy(alpha = .7f),
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Black,
                )
                Text(program.title, color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.Bold, maxLines = 2)
                val minutes = maxOf(1, ceil(maxOf(program.duration, program.end - program.start) / 60).toInt())
                Text(
                    if (program.isCommercialBreak) "$minutes MIN BREAK" else "${(program.mediaType ?: program.kind ?: "PROGRAM").uppercase()}  ·  $minutes MIN",
                    color = TaterColors.SecondaryText,
                    fontSize = 12.sp,
                )
                if (isCurrent) ProgressBar(program.progress(elapsed) * 100f)
            }
        }
    }
}

@Composable
private fun GuidePlaceholder(position: Int, modifier: Modifier) {
    GlassSurface(modifier.fillMaxHeight(), 20.dp) {
        Column(Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.Bottom) {
            Text(if (position == 1) "UP NEXT" else "LATER", color = Color.White.copy(alpha = .4f), fontSize = 12.sp, fontWeight = FontWeight.Bold)
            Text("Schedule updating", color = Color.White.copy(alpha = .6f), fontSize = 17.sp, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
fun DiscoveryScreen(viewModel: PlayerViewModel) {
    val stage = viewModel.state.discoverStage
    val focusHistory = remember { mutableStateMapOf<String, String>() }
    var previousStage by remember { mutableStateOf(stage) }
    var navigationFocusRevision by remember { mutableIntStateOf(0) }

    LaunchedEffect(stage) {
        if (stage != previousStage) {
            previousStage = stage
            navigationFocusRevision++
        }
    }

    when (stage) {
        DiscoverStage.CATEGORIES -> DiscoverCategories(viewModel, focusHistory, navigationFocusRevision)
        DiscoverStage.TITLES -> DiscoverTitles(viewModel, focusHistory, navigationFocusRevision)
        DiscoverStage.RESULTS -> DiscoverResults(viewModel, focusHistory, navigationFocusRevision)
        DiscoverStage.FILES -> DiscoverFiles(viewModel, focusHistory, navigationFocusRevision)
    }
    if (viewModel.state.isPreparingDiscovery) {
        DiscoveryPreparingOverlay()
    }
}

@Composable
internal fun DiscoveryPreparingOverlay() {
    Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = .64f)), contentAlignment = Alignment.Center) {
        StatePanel(
            "Preparing your stream…",
            "Tater Tube Server is finding the best playback path.",
            loading = true,
            modifier = Modifier.width(660.dp),
        )
    }
}

@Composable
private fun DiscoverCategories(
    viewModel: PlayerViewModel,
    focusHistory: MutableMap<String, String>,
    navigationFocusRevision: Int,
) {
    val state = viewModel.state
    val movieCategories = state.discoverCategories.filterNot(::isSeriesDiscoverCategory)
    val seriesCategories = state.discoverCategories.filter(::isSeriesDiscoverCategory)
    val firstCategoryId = (movieCategories.firstOrNull() ?: seriesCategories.firstOrNull())?.id
    val focusScope = "discover:categories"
    val focusTargetId = focusHistory[focusScope]?.takeIf { remembered ->
        state.discoverCategories.any { it.id == remembered }
    } ?: firstCategoryId
    val categoryFocusRequesters = remember(state.discoverCategories.map { it.id }) {
        state.discoverCategories.associate { it.id to FocusRequester() }
    }
    val initialFocus = focusTargetId?.let(categoryFocusRequesters::get) ?: remember { FocusRequester() }
    var restoringNavigationFocus by remember(focusScope, navigationFocusRevision) {
        mutableStateOf(navigationFocusRevision > 0)
    }
    var highlightedCategory by remember(state.discoverCategories, focusTargetId) {
        mutableStateOf(state.discoverCategories.firstOrNull { it.id == focusTargetId } ?: movieCategories.firstOrNull() ?: seriesCategories.firstOrNull())
    }

    Box(Modifier.fillMaxSize()) {
        DiscoveryLandingBackdrop(highlightedCategory)

        if (state.discoverCategories.isEmpty()) {
            Box(
                Modifier.fillMaxSize().padding(start = 52.dp, end = 52.dp, top = 96.dp, bottom = 52.dp),
                contentAlignment = Alignment.Center,
            ) {
                StatePanel(
                    if (state.isDiscoverRefreshing) "Finding something good…" else "Nothing to discover yet",
                    "Set up NZB streaming on Tater Tube Server to browse new movies and television.",
                    state.isDiscoverRefreshing,
                )
            }
        } else {
            Column(
                Modifier.fillMaxSize().padding(start = 70.dp, end = 70.dp, top = 44.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp),
            ) {
                DiscoveryLandingHero(highlightedCategory)

                if (movieCategories.isNotEmpty()) {
                    DiscoveryCategoryRail(
                        title = "MOVIES",
                        categories = movieCategories,
                        viewModel = viewModel,
                        focusRequesters = categoryFocusRequesters,
                        onFocus = {
                            highlightedCategory = it
                            if (!restoringNavigationFocus) focusHistory[focusScope] = it.id
                        },
                    )
                }

                if (seriesCategories.isNotEmpty()) {
                    DiscoveryCategoryRail(
                        title = "SERIES",
                        categories = seriesCategories,
                        viewModel = viewModel,
                        focusRequesters = categoryFocusRequesters,
                        onFocus = {
                            highlightedCategory = it
                            if (!restoringNavigationFocus) focusHistory[focusScope] = it.id
                        },
                    )
                }
            }
        }
    }
    RestoreInitialFocus(
        requester = initialFocus,
        focusKey = "discover-categories:$focusTargetId",
        enabled = focusTargetId != null && !state.menuVisible && state.selectedMedia == null && !state.isPreparingDiscovery,
    )
    LaunchedEffect(navigationFocusRevision, focusTargetId, state.isPreparingDiscovery) {
        if (navigationFocusRevision <= 0 || focusTargetId == null || state.isPreparingDiscovery) return@LaunchedEffect
        delay(80)
        categoryFocusRequesters[focusTargetId]?.let { runCatching { it.requestFocus() } }
        restoringNavigationFocus = false
    }
    LaunchedEffect(Unit) { viewModel.refreshDiscoverCatalog() }
}

@Composable
private fun DiscoveryLandingBackdrop(category: DiscoverCategory?) {
    val colors = discoveryPalette(category)
    Box(
        Modifier
            .fillMaxSize()
            .background(Brush.horizontalGradient(colors))
            .background(
                Brush.horizontalGradient(
                    listOf(Color.Black.copy(alpha = .96f), Color.Black.copy(alpha = .55f), Color.Transparent)
                )
            )
            .background(
                Brush.verticalGradient(
                    listOf(Color.Transparent, Color.Black.copy(alpha = .25f), Color.Black.copy(alpha = .96f), Color.Black)
                )
            )
    )
}

@Composable
private fun DiscoveryLandingHero(category: DiscoverCategory?) {
    Column(
        Modifier.fillMaxWidth().height(280.dp),
        verticalArrangement = Arrangement.Bottom,
    ) {
        Text(discoveryEyebrow(category), color = TaterColors.OrangeBright, fontSize = 17.sp, fontWeight = FontWeight.Bold, letterSpacing = 2.4.sp)
        Spacer(Modifier.height(11.dp))
        Text(category?.title ?: "Find your next favorite.", color = Color.White, fontSize = 50.sp, fontWeight = FontWeight.Bold, maxLines = 1)
        Spacer(Modifier.height(10.dp))
        Text(
            category?.detail ?: "Choose a collection, pick a title, then select the release that fits your screen and sound system.",
            color = Color.White.copy(alpha = .78f),
            fontSize = 20.sp,
            lineHeight = 27.sp,
            maxLines = 3,
            modifier = Modifier.width(850.dp),
        )
    }
}

@Composable
private fun DiscoveryCategoryRail(
    title: String,
    categories: List<DiscoverCategory>,
    viewModel: PlayerViewModel,
    focusRequesters: Map<String, FocusRequester>,
    onFocus: (DiscoverCategory) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(7.dp)) {
        Text(title, color = Color.White, fontSize = 25.sp, fontWeight = FontWeight.Bold, letterSpacing = 3.sp)
        LazyRow(
            horizontalArrangement = Arrangement.spacedBy(24.dp),
            contentPadding = PaddingValues(horizontal = 8.dp, vertical = 10.dp),
        ) {
            items(categories, key = { it.id }) { category ->
                DiscoveryCategoryCard(
                    category = category,
                    viewModel = viewModel,
                    modifier = Modifier.focusRequester(focusRequesters.getValue(category.id)),
                    onFocus = { focused -> if (focused) onFocus(category) },
                )
            }
        }
    }
}

@Composable
private fun DiscoveryCategoryCard(
    category: DiscoverCategory,
    viewModel: PlayerViewModel,
    modifier: Modifier = Modifier,
    onFocus: (Boolean) -> Unit = {},
) {
    FocusCard(
        onClick = { viewModel.openDiscoverCategory(category) },
        modifier = modifier.width(500.dp).height(166.dp),
        radius = 22.dp,
        onFocus = onFocus,
    ) {
        Box(
            Modifier
                .fillMaxSize()
                .background(Brush.horizontalGradient(discoveryPalette(category)))
                .background(
                    Brush.horizontalGradient(
                        listOf(Color.Black.copy(alpha = .92f), Color.Black.copy(alpha = .42f), Color.Transparent)
                    )
                )
        ) {
            Column(
                Modifier.align(Alignment.BottomStart).padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text(discoveryCardEyebrow(category), color = TaterColors.OrangeBright, fontSize = 12.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.4.sp)
                Text(category.title, color = Color.White, fontSize = 25.sp, fontWeight = FontWeight.Bold, maxLines = 1)
                Text(category.detail ?: "Browse this collection", color = Color.White.copy(alpha = .68f), fontSize = 15.sp, maxLines = 1)
            }
        }
    }
}

private fun isSeriesDiscoverCategory(category: DiscoverCategory): Boolean =
    category.category.equals("series", true) || category.id.startsWith("series:", true) || category.artworkKey.endsWith("-tv")

private fun discoveryEyebrow(category: DiscoverCategory?): String = when (category?.artworkKey) {
    "popular-movies" -> "WHAT EVERYONE’S WATCHING"
    "new-movies" -> "FRESH MOVIE RELEASES"
    "featured-movies" -> "HIGHLY RATED MOVIES"
    "popular-tv" -> "SERIES PEOPLE LOVE"
    "new-tv" -> "NEW & RETURNING SERIES"
    "featured-tv" -> "HIGHLY RATED SERIES"
    else -> "DISCOVER"
}

private fun discoveryCardEyebrow(category: DiscoverCategory): String = when (category.artworkKey) {
    "popular-movies", "popular-tv" -> "TRENDING NOW"
    "new-movies" -> "FRESH RELEASES"
    "new-tv" -> "NEW & RETURNING"
    else -> "HIGHLY RATED"
}

private fun discoveryPalette(category: DiscoverCategory?): List<Color> = when (category?.artworkKey) {
    "new-movies" -> listOf(Color(0xFF0D152A), Color(0xFF403878), Color(0xFF52245C))
    "featured-movies" -> listOf(Color(0xFF151207), Color(0xFF6B4A14), Color(0xFF894610))
    "popular-tv" -> listOf(Color(0xFF081A17), Color(0xFF17574D), Color(0xFF1A5963))
    "new-tv" -> listOf(Color(0xFF0D0F21), Color(0xFF402E6B), Color(0xFF6B2959))
    "featured-tv" -> listOf(Color(0xFF1C0A0D), Color(0xFF6D2630), Color(0xFF803829))
    else -> listOf(Color(0xFF08151C), Color(0xFF2E616F), Color(0xFF8A3D14))
}

@Composable
private fun DiscoverTitles(
    viewModel: PlayerViewModel,
    focusHistory: MutableMap<String, String>,
    navigationFocusRevision: Int,
) {
    val state = viewModel.state
    val category = state.discoverCategory ?: return
    val items = state.discoverPage?.items.orEmpty()
    val firstItemId = items.firstOrNull()?.id
    val focusScope = "discover:titles:${category.id}"
    val focusTargetId = focusHistory[focusScope]?.takeIf { remembered -> items.any { it.id == remembered } } ?: firstItemId
    val itemFocusRequesters = remember(focusScope, items.map { it.id }) {
        items.associate { it.id to FocusRequester() }
    }
    val titleGridState = rememberLazyGridState()
    val initialFocus = focusTargetId?.let(itemFocusRequesters::get) ?: remember(focusScope) { FocusRequester() }
    var restoringNavigationFocus by remember(focusScope, navigationFocusRevision) {
        mutableStateOf(navigationFocusRevision > 0)
    }
    Column(
        Modifier.fillMaxSize().padding(start = 58.dp, end = 58.dp, top = 84.dp, bottom = 48.dp),
        verticalArrangement = Arrangement.spacedBy(24.dp),
    ) {
        if (items.isEmpty()) StatePanel("Loading ${category.title}…", "Your cached collection appears first whenever available.", state.isDiscoverRefreshing)
        else LazyVerticalGrid(
            columns = GridCells.Adaptive(248.dp),
            modifier = Modifier.weight(1f),
            state = titleGridState,
            horizontalArrangement = Arrangement.spacedBy(22.dp),
            verticalArrangement = Arrangement.spacedBy(26.dp),
            contentPadding = PaddingValues(horizontal = 12.dp, vertical = 18.dp),
        ) {
            items(items, key = { it.id }) { item ->
                PosterCard(
                    item,
                    viewModel,
                    modifier = Modifier.focusRequester(itemFocusRequesters.getValue(item.id)),
                    onFocus = { focused ->
                        if (focused && !restoringNavigationFocus) focusHistory[focusScope] = item.id
                    },
                ) {
                    // Record the exact title before the screen changes. This
                    // remains reliable even if focus callbacks race the
                    // navigation transition.
                    focusHistory[focusScope] = item.id
                    viewModel.openDiscoverTitle(item)
                }
            }
        }
    }
    RestoreInitialFocus(
        requester = initialFocus,
        focusKey = "discover-titles:$focusTargetId",
        enabled = focusTargetId != null && !state.menuVisible && state.selectedMedia == null && !state.isPreparingDiscovery,
    )
    LaunchedEffect(navigationFocusRevision, focusTargetId, state.isPreparingDiscovery) {
        if (navigationFocusRevision <= 0 || focusTargetId == null || state.isPreparingDiscovery) return@LaunchedEffect
        val returnIndex = items.indexOfFirst { it.id == focusTargetId }
        if (returnIndex < 0) return@LaunchedEffect
        delay(80)
        titleGridState.scrollToItem(returnIndex)
        withFrameNanos { }
        itemFocusRequesters[focusTargetId]?.let { runCatching { it.requestFocus() } }
        withFrameNanos { }
        titleGridState.scrollToItem(returnIndex)
        restoringNavigationFocus = false
    }
}

@Composable
private fun DiscoverResults(
    viewModel: PlayerViewModel,
    focusHistory: MutableMap<String, String>,
    navigationFocusRevision: Int,
) {
    val state = viewModel.state
    val title = state.discoverTitle ?: return
    val results = state.discoverPage?.items.orEmpty()
    val firstResultId = results.firstOrNull()?.id
    val focusScope = "discover:results:${title.id}"
    val focusTargetId = focusHistory[focusScope]?.takeIf { remembered -> results.any { it.id == remembered } } ?: firstResultId
    val resultFocusRequesters = remember(focusScope, results.map { it.id }) {
        results.associate { it.id to FocusRequester() }
    }
    val initialFocus = focusTargetId?.let(resultFocusRequesters::get) ?: remember(focusScope) { FocusRequester() }
    val emptyResultFocus = remember(focusScope) { FocusRequester() }
    var restoringNavigationFocus by remember(focusScope, navigationFocusRevision) {
        mutableStateOf(navigationFocusRevision > 0)
    }
    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(70.dp, 80.dp, 70.dp, 80.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        item { DiscoveryTitleHero(title, viewModel) }
        if (results.isEmpty()) item {
            Column(
                Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(18.dp),
            ) {
                StatePanel(
                    title = if (state.isDiscoverRefreshing) "Finding releases…" else "No releases found",
                    message = if (state.isDiscoverRefreshing) {
                        "Searching for the complete title now."
                    } else {
                        "Tater Tube could not find an available release for ${title.title}."
                    },
                    loading = state.isDiscoverRefreshing,
                )
                TaterButton(
                    text = if (state.isDiscoverRefreshing) "CANCEL SEARCH" else "BACK TO TITLES",
                    onClick = viewModel::handleBack,
                    modifier = Modifier.focusRequester(emptyResultFocus).width(250.dp),
                )
            }
        }
        else items(results, key = { it.id }) { release ->
            ReleaseRow(
                release,
                modifier = Modifier.focusRequester(resultFocusRequesters.getValue(release.id)),
                onFocus = { focused ->
                    if (focused && !restoringNavigationFocus) focusHistory[focusScope] = release.id
                },
            ) { viewModel.prepareDiscoverRelease(release) }
        }
    }
    RestoreInitialFocus(
        requester = initialFocus,
        focusKey = "discover-results:$focusTargetId",
        enabled = focusTargetId != null && !state.menuVisible && state.selectedMedia == null && !state.isPreparingDiscovery,
    )
    LaunchedEffect(navigationFocusRevision, focusTargetId, state.isPreparingDiscovery) {
        if (navigationFocusRevision <= 0 || focusTargetId == null || state.isPreparingDiscovery) return@LaunchedEffect
        delay(80)
        resultFocusRequesters[focusTargetId]?.let { runCatching { it.requestFocus() } }
        restoringNavigationFocus = false
    }
    LaunchedEffect(results.isEmpty(), state.isDiscoverRefreshing) {
        if (!results.isEmpty()) return@LaunchedEffect
        delay(80)
        runCatching { emptyResultFocus.requestFocus() }
        restoringNavigationFocus = false
    }
}

@Composable
private fun DiscoveryTitleHero(item: MediaItem, viewModel: PlayerViewModel) {
    GlassSurface(Modifier.fillMaxWidth().height(220.dp), 28.dp) {
        Row(Modifier.fillMaxSize().padding(22.dp), horizontalArrangement = Arrangement.spacedBy(24.dp)) {
            TaterArtwork(item, viewModel.artworkUrl(item), viewModel.token, Modifier.width(128.dp).fillMaxHeight().clip(RoundedCornerShape(16.dp)))
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(9.dp)) {
                Text(item.title, color = Color.White, fontSize = 29.sp, fontWeight = FontWeight.Bold, maxLines = 2)
                Text("CHOOSE A RELEASE", color = TaterColors.OrangeBright, fontSize = 14.sp, fontWeight = FontWeight.Bold)
                item.summary?.let { Text(it, color = TaterColors.SecondaryText, fontSize = 15.sp, lineHeight = 21.sp, maxLines = 4) }
            }
        }
    }
}

@Composable
private fun ReleaseRow(
    release: MediaItem,
    modifier: Modifier = Modifier,
    onFocus: (Boolean) -> Unit = {},
    onClick: () -> Unit,
) {
    FocusCard(onClick, modifier.fillMaxWidth(), 20.dp, onFocus) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 22.dp, vertical = 17.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(72.dp).background(TaterColors.Orange.copy(alpha = .15f), RoundedCornerShape(15.dp)), contentAlignment = Alignment.Center) {
                Text("▶", color = TaterColors.OrangeBright, fontSize = 27.sp)
            }
            Column(Modifier.weight(1f).padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
                Text(release.title, color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.Bold, maxLines = 2)
                val metadata = listOfNotNull(
                    release.sizeText ?: release.subtitle,
                    release.files?.let { "$it ${if (it == "1") "file" else "files"}" },
                    release.grabs?.let { "$it ${if (it == "1") "grab" else "grabs"}" },
                ).joinToString("  ·  ")
                Text(metadata, color = TaterColors.SecondaryText, fontSize = 14.sp, maxLines = 1)
            }
            Text("›", color = TaterColors.OrangeBright, fontSize = 30.sp, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
private fun DiscoverFiles(
    viewModel: PlayerViewModel,
    focusHistory: MutableMap<String, String>,
    navigationFocusRevision: Int,
) {
    val state = viewModel.state
    val firstFileId = state.preparedFiles.firstOrNull()?.id
    val focusScope = "discover:files"
    val focusTargetId = focusHistory[focusScope]?.takeIf { remembered ->
        state.preparedFiles.any { it.id == remembered }
    } ?: firstFileId
    val fileFocusRequesters = remember(state.preparedFiles.map { it.id }) {
        state.preparedFiles.associate { it.id to FocusRequester() }
    }
    val initialFocus = focusTargetId?.let(fileFocusRequesters::get) ?: remember { FocusRequester() }
    var restoringNavigationFocus by remember(focusScope, navigationFocusRevision) {
        mutableStateOf(navigationFocusRevision > 0)
    }
    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(90.dp, 104.dp, 90.dp, 80.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        item { DiscoveryHero("Choose a file", "This release contains more than one playable video.") }
        items(state.preparedFiles, key = { it.id }) { file ->
            ReleaseRow(
                file.playbackItem.copy(title = file.filename, sizeText = null, files = null, grabs = null),
                modifier = Modifier.focusRequester(fileFocusRequesters.getValue(file.id)),
                onFocus = { focused ->
                    if (focused && !restoringNavigationFocus) focusHistory[focusScope] = file.id
                },
            ) {
                viewModel.playPreparedFile(file)
            }
        }
    }
    RestoreInitialFocus(
        requester = initialFocus,
        focusKey = "discover-files:$focusTargetId",
        enabled = focusTargetId != null && !state.menuVisible && state.selectedMedia == null && !state.isPreparingDiscovery,
    )
    LaunchedEffect(navigationFocusRevision, focusTargetId, state.isPreparingDiscovery) {
        if (navigationFocusRevision <= 0 || focusTargetId == null || state.isPreparingDiscovery) return@LaunchedEffect
        delay(80)
        fileFocusRequesters[focusTargetId]?.let { runCatching { it.requestFocus() } }
        restoringNavigationFocus = false
    }
}

@Composable
private fun DiscoveryHero(title: String, message: String) {
    GlassSurface(Modifier.fillMaxWidth().height(180.dp), 28.dp) {
        Row(Modifier.fillMaxSize().padding(horizontal = 30.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(title, color = Color.White, fontSize = 31.sp, fontWeight = FontWeight.Bold)
                Text(message, color = TaterColors.SecondaryText, fontSize = 16.sp, lineHeight = 23.sp, maxLines = 3)
            }
        }
    }
}

@Composable
fun TaterPicksScreen(viewModel: PlayerViewModel) {
    val state = viewModel.state
    val recommendations = state.recommendations.sortedBy { it.rank }
    val firstPickId = recommendations.firstOrNull()?.id
    var focusTargetId by remember(state.recommendationBatch?.id, recommendations.map { it.id }) {
        mutableStateOf(state.taterPicksFocusId?.takeIf { remembered -> recommendations.any { it.id == remembered } } ?: firstPickId)
    }
    var focused by remember(state.recommendationBatch?.id, recommendations) {
        mutableStateOf(recommendations.firstOrNull { it.id == focusTargetId } ?: recommendations.firstOrNull())
    }
    val pickFocusRequesters = remember(state.recommendationBatch?.id, recommendations.map { it.id }) {
        recommendations.associate { it.id to FocusRequester() }
    }
    val initialFocus = focusTargetId?.let(pickFocusRequesters::get) ?: remember { FocusRequester() }
    val rails = remember(recommendations) { buildTaterPickRails(recommendations) }
    var detailsWereOpen by remember(state.recommendationBatch?.id) { mutableStateOf(false) }
    var detailReturnPickId by remember(state.recommendationBatch?.id) { mutableStateOf<String?>(null) }

    Box(Modifier.fillMaxSize()) {
        TaterPicksBackdrop(focused?.launch, viewModel)

        if (recommendations.isEmpty()) {
            Box(
                Modifier.fillMaxSize().padding(start = 52.dp, end = 52.dp, top = 96.dp, bottom = 52.dp),
                contentAlignment = Alignment.Center,
            ) {
                StatePanel(
                    if (state.isRecommendationsRefreshing) "Tater is checking your shelves…" else "Tater is still getting to know you",
                    "Watch a few movies, shows, or Tube TV programs and Tater Core will prepare picks on its next schedule.",
                    state.isRecommendationsRefreshing,
                )
            }
        } else {
            Column(
                Modifier.fillMaxSize().padding(start = 70.dp, end = 70.dp, top = 44.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp),
            ) {
                PicksHero(focused, viewModel)

                rails.forEach { rail ->
                    TaterPicksRail(
                        rail = rail,
                        viewModel = viewModel,
                        focusRequesters = pickFocusRequesters,
                        onFocus = {
                            focused = it
                            if (!detailsWereOpen) {
                                focusTargetId = it.id
                                viewModel.rememberTaterPicksFocus(it.id)
                            }
                        },
                    )
                }
            }
        }
    }
    RestoreInitialFocus(
        requester = initialFocus,
        focusKey = "picks:$focusTargetId",
        enabled = focusTargetId != null && !state.menuVisible && state.selectedMedia == null,
    )
    LaunchedEffect(state.returningToTaterPicks, focusTargetId) {
        if (!state.returningToTaterPicks || focusTargetId == null) return@LaunchedEffect
        delay(80)
        pickFocusRequesters[focusTargetId]?.let { runCatching { it.requestFocus() } }
        viewModel.completeTaterPicksReturn()
    }
    LaunchedEffect(state.selectedMedia?.id) {
        if (state.selectedMedia != null) {
            detailReturnPickId = focusTargetId
            detailsWereOpen = true
        } else if (detailsWereOpen) {
            val returnId = detailReturnPickId
            delay(80)
            pickFocusRequesters[returnId]?.let { runCatching { it.requestFocus() } }
            focusTargetId = returnId ?: focusTargetId
            detailReturnPickId = null
            detailsWereOpen = false
        }
    }
    LaunchedEffect(Unit) { viewModel.refreshRecommendations() }
}

private data class TaterPickRailModel(
    val id: String,
    val title: String,
    val detail: String,
    val items: List<RecommendationItem>,
)

private fun buildTaterPickRails(items: List<RecommendationItem>): List<TaterPickRailModel> {
    val movies = items.filter { isMoviePick(it.launch) }
    val series = items.filter { isSeriesPick(it.launch) }
    val classified = (movies + series).mapTo(mutableSetOf()) { it.id }
    val other = items.filterNot { it.id in classified }

    if (movies.isNotEmpty() && series.isNotEmpty()) {
        return listOf(
            TaterPickRailModel("movie-picks", "MOVIE PICKS", "Hand-picked for movie night", movies + other),
            TaterPickRailModel("series-picks", "SERIES PICKS", "Your next great series", series),
        )
    }

    if (items.size <= 1) {
        return listOf(TaterPickRailModel("top-picks", "TATER’S PICKS", "Chosen for you", items))
    }
    val split = ((items.size + 1) / 2).coerceAtLeast(1)
    return listOf(
        TaterPickRailModel("top-picks", "TATER’S TOP PICKS", "Start with these", items.take(split)),
        TaterPickRailModel("more-picks", "MORE FOR YOU", "Keep exploring", items.drop(split)),
    ).filter { it.items.isNotEmpty() }
}

private fun isMoviePick(item: MediaItem): Boolean =
    (item.mediaType ?: item.type).orEmpty().lowercase() in setOf("movie", "film")

private fun isSeriesPick(item: MediaItem): Boolean =
    (item.mediaType ?: item.type).orEmpty().lowercase() in setOf("show", "series", "tv", "tvshow", "season", "episode")

@Composable
private fun TaterPicksBackdrop(item: MediaItem?, viewModel: PlayerViewModel) {
    Box(
        Modifier.fillMaxSize().background(Color.Black),
        contentAlignment = Alignment.TopStart,
    ) {
        if (item != null) {
            TaterArtwork(
                item = item,
                artworkUrl = viewModel.wideArtworkUrl(item),
                token = viewModel.token,
                modifier = Modifier.fillMaxWidth().height(804.dp),
                contentScale = ContentScale.Crop,
                backgroundColor = Color.Black,
            )
        }
        Box(
            Modifier
                .fillMaxSize()
                .background(
                    Brush.horizontalGradient(
                        listOf(Color.Black.copy(alpha = .97f), Color.Black.copy(alpha = .56f), Color.Transparent)
                    )
                )
                .background(
                    Brush.verticalGradient(
                        listOf(Color.Transparent, Color.Black.copy(alpha = .22f), Color.Black.copy(alpha = .96f), Color.Black)
                    )
                )
        )
    }
}

@Composable
private fun TaterPicksRail(
    rail: TaterPickRailModel,
    viewModel: PlayerViewModel,
    focusRequesters: Map<String, FocusRequester>,
    onFocus: (RecommendationItem) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(7.dp)) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.SpaceBetween) {
            Text(rail.title, color = Color.White, fontSize = 25.sp, fontWeight = FontWeight.Bold, letterSpacing = 3.sp)
            Text(rail.detail, color = Color.White.copy(alpha = .58f), fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
        }
        LazyRow(
            horizontalArrangement = Arrangement.spacedBy(24.dp),
            contentPadding = PaddingValues(horizontal = 8.dp, vertical = 10.dp),
        ) {
            items(rail.items, key = { it.id }) { recommendation ->
                PickCard(
                    recommendation = recommendation,
                    viewModel = viewModel,
                    modifier = Modifier.focusRequester(focusRequesters.getValue(recommendation.id)),
                    onFocus = { active -> if (active) onFocus(recommendation) },
                ) { viewModel.activateRecommendation(recommendation) }
            }
        }
    }
}

@Composable
private fun PicksHero(focused: RecommendationItem?, viewModel: PlayerViewModel) {
    val state = viewModel.state
    val batch = state.recommendationBatch
    val item = focused?.launch
    Column(
        Modifier.fillMaxWidth().height(300.dp),
        verticalArrangement = Arrangement.Bottom,
    ) {
        Text(
            if (focused == null) "A NOTE FROM ${(batch?.assistantName ?: "TATER").uppercase()}" else "WHY ${(batch?.assistantName ?: "TATER").uppercase()} PICKED THIS",
            color = TaterColors.OrangeBright,
            fontSize = 17.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = 2.4.sp,
        )
        Spacer(Modifier.height(10.dp))
        Text(focused?.title ?: "Tater Picks", color = Color.White, fontSize = 48.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)

        val metadata = listOfNotNull(
            item?.date?.takeIf(String::isNotBlank),
            item?.contentRating?.takeIf(String::isNotBlank),
        ).joinToString("  •  ")
        if (metadata.isNotBlank()) {
            Spacer(Modifier.height(8.dp))
            Text(metadata, color = Color.White.copy(alpha = .78f), fontSize = 18.sp, fontWeight = FontWeight.SemiBold)
        }

        val message = focused?.reason ?: batch?.summary?.takeIf(String::isNotBlank) ?: batch?.picksBriefing.orEmpty()
        if (message.isNotBlank()) {
            Spacer(Modifier.height(8.dp))
            Text(message, color = Color.White.copy(alpha = .82f), fontSize = 19.sp, lineHeight = 25.sp, maxLines = 3, modifier = Modifier.width(850.dp))
        }

        if (item != null) {
            val chips = cinematicMediaChips(item)
            if (chips.isNotEmpty()) {
                Spacer(Modifier.height(10.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    chips.forEach { InfoChip(it) }
                }
            }
        }

        val speech = when (val value = state.speechState) {
            TaterSpeechState.Idle -> "${state.recommendations.size} picks for you"
            TaterSpeechState.Loading -> "Getting Tater's voice…"
            TaterSpeechState.Speaking -> "Tater is speaking"
            is TaterSpeechState.Failed -> value.message
        }
        Spacer(Modifier.height(9.dp))
        Text(speech, color = Color.White.copy(alpha = .58f), fontSize = 13.sp, maxLines = 1)
    }
}

@Composable
private fun PickCard(
    recommendation: RecommendationItem,
    viewModel: PlayerViewModel,
    modifier: Modifier = Modifier,
    onFocus: (Boolean) -> Unit,
    onClick: () -> Unit,
) {
    FocusCard(onClick, modifier.width(360.dp).height(203.dp), 22.dp, onFocus) {
        Box(Modifier.fillMaxSize()) {
            TaterArtwork(
                recommendation.launch,
                viewModel.wideArtworkUrl(recommendation.launch),
                viewModel.token,
                Modifier.fillMaxSize(),
            )
            Box(
                Modifier.fillMaxSize().background(
                    Brush.verticalGradient(
                        listOf(Color.Transparent, Color.Black.copy(alpha = .20f), Color.Black.copy(alpha = .94f))
                    )
                )
            )
            Column(
                Modifier.align(Alignment.BottomStart).padding(19.dp),
                verticalArrangement = Arrangement.spacedBy(5.dp),
            ) {
                Text("TATER PICK  •  ${(recommendation.mediaType ?: recommendation.launch.mediaType ?: "VIDEO").uppercase()}", color = TaterColors.OrangeBright, fontSize = 11.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.2.sp)
                Text(recommendation.title, color = Color.White, fontSize = 23.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text(recommendation.reason, color = Color.White.copy(alpha = .70f), fontSize = 14.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            Text(
                "%02d".format(maxOf(1, recommendation.rank)),
                color = Color.White,
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.align(Alignment.TopEnd).padding(11.dp)
                    .background(TaterColors.Orange.copy(alpha = .9f), RoundedCornerShape(12.dp)).padding(horizontal = 9.dp, vertical = 5.dp),
            )
        }
    }
}

@Composable
private fun DestinationCard(title: String, glyph: String, onClick: () -> Unit) {
    FocusCard(onClick, Modifier.width(190.dp).height(202.dp), 22.dp) {
        Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
            Text(glyph, color = TaterColors.OrangeBright, fontSize = 54.sp, fontWeight = FontWeight.Bold)
            Text(title, color = Color.White, fontSize = 23.sp, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
private fun FocusCard(
    onClick: (() -> Unit)?,
    modifier: Modifier = Modifier,
    radius: androidx.compose.ui.unit.Dp = 20.dp,
    onFocus: (Boolean) -> Unit = {},
    content: @Composable () -> Unit,
) {
    var focused by remember { mutableStateOf(false) }
    val border by animateColorAsState(if (focused) TaterColors.OrangeBright else Color.White.copy(alpha = .1f), label = "focus-border")
    val scale by animateFloatAsState(if (focused) 1.025f else 1f, label = "focus-scale")
    val shape = RoundedCornerShape(radius)
    Box(
        modifier
            .onFocusChanged { focused = it.isFocused; onFocus(it.isFocused) }
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
            }
            .taterFocusGlow(focused, shape)
            .clip(shape)
            .background(TaterColors.Glass)
            .border(if (focused) 4.dp else 1.dp, border, shape)
    ) { content() }
}

@Composable
private fun ForceFocusOnRevision(
    requester: FocusRequester,
    revision: Int,
    enabled: Boolean,
) {
    LaunchedEffect(revision, enabled) {
        if (revision <= 0 || !enabled) return@LaunchedEffect
        delay(80)
        runCatching { requester.requestFocus() }
    }
}

@Composable
private fun ProgressBar(percent: Float) {
    if (percent <= .5f) return
    Box(Modifier.fillMaxWidth().height(5.dp).background(Color.White.copy(alpha = .18f), RoundedCornerShape(3.dp))) {
        Box(Modifier.fillMaxWidth((percent / 100f).coerceIn(0f, 1f)).height(5.dp).background(TaterColors.Orange, RoundedCornerShape(3.dp)))
    }
}

@Composable
private fun StatePanel(
    title: String,
    message: String,
    loading: Boolean = false,
    modifier: Modifier = Modifier.fillMaxWidth(),
) {
    GlassSurface(modifier.height(210.dp), 28.dp) {
        Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
            if (loading) LoadingDots()
            else Text("✦", color = TaterColors.OrangeBright, fontSize = 30.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(10.dp))
            Text(title, color = Color.White, fontSize = 25.sp, fontWeight = FontWeight.Bold)
            Text(message, color = TaterColors.SecondaryText, fontSize = 15.sp, modifier = Modifier.padding(top = 8.dp))
        }
    }
}

@Composable
private fun LoadingDots() {
    val animation = rememberInfiniteTransition(label = "loading-dots")
    Row(
        Modifier.height(30.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        repeat(3) { index ->
            val lift by animation.animateFloat(
                initialValue = 0f,
                targetValue = 1f,
                animationSpec = infiniteRepeatable(
                    animation = tween(durationMillis = 420, delayMillis = index * 120),
                    repeatMode = RepeatMode.Reverse,
                ),
                label = "loading-dot-$index",
            )
            Box(
                Modifier
                    .size(10.dp)
                    .graphicsLayer {
                        translationY = -6.dp.toPx() * lift
                        scaleX = 0.82f + (0.18f * lift)
                        scaleY = scaleX
                        alpha = 0.48f + (0.52f * lift)
                    }
                    .background(TaterColors.OrangeBright, CircleShape)
            )
        }
    }
}

private fun List<MediaItem>.naturalOrder(): List<MediaItem> = sortedWith { left, right ->
    naturalTokens(left.title).zip(naturalTokens(right.title)).firstOrNull { (a, b) -> a != b }?.let { (a, b) ->
        val ai = a.toIntOrNull()
        val bi = b.toIntOrNull()
        when {
            ai != null && bi != null -> ai.compareTo(bi)
            else -> a.compareTo(b, ignoreCase = true)
        }
    } ?: left.title.length.compareTo(right.title.length)
}

private fun naturalTokens(value: String): List<String> = Regex("(\\d+|\\D+)").findAll(value).map { it.value }.toList()
private fun Date.formatTime(): String = SimpleDateFormat("h:mm a", Locale.getDefault()).format(this).uppercase()
