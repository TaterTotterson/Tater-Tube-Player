package com.tatertotterson.tatertubeplayer.ui

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.tv.material3.Text
import com.tatertotterson.tatertubeplayer.R
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
import com.tatertotterson.tatertubeplayer.ui.components.SectionHeading
import com.tatertotterson.tatertubeplayer.ui.components.TaterArtwork
import com.tatertotterson.tatertubeplayer.ui.components.TaterButton
import com.tatertotterson.tatertubeplayer.ui.theme.TaterColors
import kotlinx.coroutines.delay
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.ceil

@Composable
fun LibraryScreen(viewModel: PlayerViewModel) {
    val state = viewModel.state
    val location = state.libraryStack.lastOrNull()
    if (location == null) LibraryOverview(viewModel) else LibraryCollection(location, viewModel)
}

@Composable
private fun LibraryOverview(viewModel: PlayerViewModel) {
    val state = viewModel.state
    val home = state.home ?: return
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
                    TaterButton("All Movies", { viewModel.openLibrary(LibraryLocation.AllMovies) }, Modifier.weight(1f))
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
}

@Composable
private fun LibraryShelf(row: LibraryRow, viewModel: PlayerViewModel) {
    val parent = LibraryLocation.fromEntry(row.entry)
    Column {
        SectionHeading(row.title)
        LazyRow(horizontalArrangement = Arrangement.spacedBy(18.dp)) {
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
private fun LibraryCollection(location: LibraryLocation, viewModel: PlayerViewModel) {
    val state = viewModel.state
    val page = state.libraryPages[location.cacheKey]
    val items = page?.items.orEmpty().naturalOrder()
    val isEpisodePage = items.isNotEmpty() && items.count { it.isEpisode } >= items.size / 2
    val showHero = location.mediaType.orEmpty().lowercase() in setOf("show", "series", "season", "tvshow")

    Box(Modifier.fillMaxSize()) {
        if (showHero && !location.backdrop.isNullOrBlank()) {
            TaterArtwork(
                item = MediaItem("background", location.title, backdrop = location.backdrop),
                artworkUrl = viewModel.resolveArtworkUrl(location.backdrop),
                token = viewModel.token,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop,
            )
            Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.74f)))
        }

        Column(
            Modifier.fillMaxSize().padding(start = 58.dp, end = 58.dp, top = 40.dp, bottom = 48.dp),
            verticalArrangement = Arrangement.spacedBy(26.dp),
        ) {
            if (showHero) CollectionHero(location, items, viewModel)

            if (page == null && state.loadingLibraryKey == location.cacheKey) {
                StatePanel("Loading ${location.title}…", "Your cached collection appears immediately when available.", true)
            } else if (items.isEmpty()) {
                StatePanel("Nothing here yet", "This collection is currently empty on Tater Tube Server.")
            } else if (isEpisodePage) {
                LazyVerticalGrid(
                    columns = GridCells.Fixed(2),
                    modifier = Modifier.weight(1f),
                    horizontalArrangement = Arrangement.spacedBy(22.dp),
                    verticalArrangement = Arrangement.spacedBy(22.dp),
                    contentPadding = PaddingValues(8.dp),
                ) {
                    items(items, key = { it.id }) { item -> EpisodeCard(item, viewModel) { viewModel.openDetails(item) } }
                }
            } else {
                LazyVerticalGrid(
                    columns = GridCells.Adaptive(188.dp),
                    modifier = Modifier.weight(1f),
                    horizontalArrangement = Arrangement.spacedBy(22.dp),
                    verticalArrangement = Arrangement.spacedBy(26.dp),
                    contentPadding = PaddingValues(8.dp),
                ) {
                    items(items, key = { it.id }) { item ->
                        PosterCard(item, viewModel) {
                            viewModel.activateLibraryItem(item, location)
                        }
                    }
                }
            }
        }
    }
    LaunchedEffect(location.cacheKey) { viewModel.loadLibraryPage(location) }
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
private fun PosterCard(item: MediaItem, viewModel: PlayerViewModel, onClick: () -> Unit) {
    FocusCard(onClick, Modifier.width(188.dp), 20.dp) {
        Column(verticalArrangement = Arrangement.spacedBy(9.dp)) {
            TaterArtwork(
                item,
                viewModel.artworkUrl(item),
                viewModel.token,
                Modifier.fillMaxWidth().height(278.dp).clip(RoundedCornerShape(17.dp)),
            )
            Text(item.title, color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Bold, maxLines = 2, overflow = TextOverflow.Ellipsis)
            val count = maxOf(item.episodeCount, item.leafCount)
            Text(
                item.resumeTitle?.let { "Continue $it" } ?: if (count > 0) "$count episodes" else item.subtitle.orEmpty(),
                color = if (item.resumeTitle != null) TaterColors.OrangeBright else TaterColors.SecondaryText,
                fontSize = 13.sp,
                maxLines = 1,
            )
            ProgressBar(item.progressPercent.toFloat())
        }
    }
}

@Composable
private fun EpisodeCard(item: MediaItem, viewModel: PlayerViewModel, onClick: () -> Unit) {
    FocusCard(onClick, Modifier.fillMaxWidth(), 22.dp) {
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
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            StatePanel(
                if (state.isLiveGuideRefreshing) "Tuning your Tater Tube guide…" else "No channels are on the guide yet",
                "Build or enable Tube TV channels on Tater Tube Server.",
                state.isLiveGuideRefreshing,
            )
        }
        return
    }
    val elapsed = guide.elapsedSeconds(clock)
    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(start = 46.dp, end = 46.dp, top = 30.dp, bottom = 80.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        stickyHeader { GuideHeader() }
        items(guide.channels, key = { it.id }) { channel -> GuideRow(channel, guide, elapsed, viewModel) }
    }
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
private fun GuideRow(channel: LiveChannel, guide: LiveGuide, elapsed: Double, viewModel: PlayerViewModel) {
    val programs = channel.displayedPrograms(elapsed)
    Row(Modifier.fillMaxWidth().height(180.dp), horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        ChannelCard(channel, viewModel, Modifier.width(210.dp))
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
    when (viewModel.state.discoverStage) {
        DiscoverStage.CATEGORIES -> DiscoverCategories(viewModel)
        DiscoverStage.TITLES -> DiscoverTitles(viewModel)
        DiscoverStage.RESULTS -> DiscoverResults(viewModel)
        DiscoverStage.FILES -> DiscoverFiles(viewModel)
    }
    if (viewModel.state.isPreparingDiscovery) {
        Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = .64f)), contentAlignment = Alignment.Center) {
            StatePanel("Preparing your stream…", "Tater Tube Server is finding the playable files.", true)
        }
    }
}

@Composable
private fun DiscoverCategories(viewModel: PlayerViewModel) {
    val state = viewModel.state
    Column(Modifier.fillMaxSize().padding(52.dp), verticalArrangement = Arrangement.spacedBy(26.dp)) {
        DiscoveryHero("Find your next favorite.", "Choose a collection, pick a title, then select a release that fits your screen and sound system.")
        if (state.discoverCategories.isEmpty()) {
            StatePanel(
                if (state.isDiscoverRefreshing) "Finding something good…" else "Nothing to discover yet",
                "Set up NZB streaming on Tater Tube Server to browse new movies and television.",
                state.isDiscoverRefreshing,
            )
        } else {
            LazyVerticalGrid(
                columns = GridCells.Fixed(3),
                modifier = Modifier.weight(1f),
                horizontalArrangement = Arrangement.spacedBy(22.dp),
                verticalArrangement = Arrangement.spacedBy(22.dp),
                contentPadding = PaddingValues(8.dp),
            ) {
                items(state.discoverCategories, key = { it.id }) { category -> DiscoveryCategoryCard(category, viewModel) }
            }
        }
    }
    LaunchedEffect(Unit) { viewModel.refreshDiscoverCatalog() }
}

@Composable
private fun DiscoveryCategoryCard(category: DiscoverCategory, viewModel: PlayerViewModel) {
    val art = when (category.artworkKey) {
        "popular-movies" -> R.drawable.discover_popular_movies
        "new-movies" -> R.drawable.discover_new_movies
        "popular-tv" -> R.drawable.discover_popular_tv
        "new-tv" -> R.drawable.discover_new_tv
        "featured-tv" -> R.drawable.discover_featured_tv
        else -> R.drawable.discover_featured_movies
    }
    FocusCard({ viewModel.openDiscoverCategory(category) }, Modifier.fillMaxWidth(), 22.dp) {
        Column(Modifier.padding(10.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Image(painterResource(art), category.title, Modifier.fillMaxWidth().height(142.dp).clip(RoundedCornerShape(17.dp)), contentScale = ContentScale.Crop)
            Text(category.title, color = Color.White, fontSize = 20.sp, fontWeight = FontWeight.Bold, maxLines = 1)
            Text(category.detail ?: "Browse this collection", color = TaterColors.SecondaryText, fontSize = 14.sp, maxLines = 1)
        }
    }
}

@Composable
private fun DiscoverTitles(viewModel: PlayerViewModel) {
    val state = viewModel.state
    val category = state.discoverCategory ?: return
    Column(Modifier.fillMaxSize().padding(52.dp), verticalArrangement = Arrangement.spacedBy(24.dp)) {
        DiscoveryHero(category.title, category.detail ?: "Choose a title to search for a playable release.")
        val items = state.discoverPage?.items.orEmpty()
        if (items.isEmpty()) StatePanel("Loading ${category.title}…", "Your cached collection appears first whenever available.", state.isDiscoverRefreshing)
        else LazyVerticalGrid(
            columns = GridCells.Adaptive(188.dp),
            modifier = Modifier.weight(1f),
            horizontalArrangement = Arrangement.spacedBy(22.dp),
            verticalArrangement = Arrangement.spacedBy(26.dp),
            contentPadding = PaddingValues(8.dp),
        ) {
            items(items, key = { it.id }) { item -> PosterCard(item, viewModel) { viewModel.openDiscoverTitle(item) } }
        }
    }
}

@Composable
private fun DiscoverResults(viewModel: PlayerViewModel) {
    val state = viewModel.state
    val title = state.discoverTitle ?: return
    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(70.dp, 36.dp, 70.dp, 80.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        item { DiscoveryTitleHero(title, viewModel) }
        val results = state.discoverPage?.items.orEmpty()
        if (results.isEmpty()) item { StatePanel("Finding releases…", "Searching for the complete title now.", state.isDiscoverRefreshing) }
        else items(results, key = { it.id }) { release -> ReleaseRow(release) { viewModel.prepareDiscoverRelease(release) } }
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
private fun ReleaseRow(release: MediaItem, onClick: () -> Unit) {
    FocusCard(onClick, Modifier.fillMaxWidth(), 20.dp) {
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
private fun DiscoverFiles(viewModel: PlayerViewModel) {
    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(90.dp, 60.dp, 90.dp, 80.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        item { DiscoveryHero("Choose a file", "This release contains more than one playable video.") }
        items(viewModel.state.preparedFiles, key = { it.id }) { file ->
            ReleaseRow(file.playbackItem.copy(title = file.filename, sizeText = null, files = null, grabs = null)) {
                viewModel.playPreparedFile(file)
            }
        }
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
            Image(painterResource(R.drawable.tater_hero_remote), null, Modifier.width(190.dp).fillMaxHeight(), contentScale = ContentScale.Fit)
        }
    }
}

@Composable
fun TaterPicksScreen(viewModel: PlayerViewModel) {
    val state = viewModel.state
    var focused by remember { mutableStateOf<RecommendationItem?>(null) }
    Column(Modifier.fillMaxSize().padding(52.dp), verticalArrangement = Arrangement.spacedBy(26.dp)) {
        PicksHero(focused, viewModel)
        if (state.recommendations.isEmpty()) {
            StatePanel(
                if (state.isRecommendationsRefreshing) "Tater is checking your shelves…" else "Tater is still getting to know you",
                "Watch a few movies, shows, or Tube TV programs and Tater Core will prepare picks on its next schedule.",
                state.isRecommendationsRefreshing,
            )
        } else {
            LazyVerticalGrid(
                columns = GridCells.Fixed(4),
                modifier = Modifier.weight(1f),
                horizontalArrangement = Arrangement.spacedBy(20.dp),
                verticalArrangement = Arrangement.spacedBy(22.dp),
                contentPadding = PaddingValues(8.dp),
            ) {
                items(state.recommendations, key = { it.id }) { recommendation ->
                    PickCard(
                        recommendation,
                        viewModel,
                        onFocus = { active -> if (active) focused = recommendation else if (focused?.id == recommendation.id) focused = null },
                    ) { viewModel.activateRecommendation(recommendation) }
                }
            }
        }
    }
    LaunchedEffect(Unit) { viewModel.refreshRecommendations() }
}

@Composable
private fun PicksHero(focused: RecommendationItem?, viewModel: PlayerViewModel) {
    val state = viewModel.state
    val batch = state.recommendationBatch
    GlassSurface(Modifier.fillMaxWidth().height(220.dp), 30.dp) {
        Row(Modifier.fillMaxSize().padding(horizontal = 32.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(9.dp)) {
                Text(
                    if (focused == null) "A NOTE FROM ${(batch?.assistantName ?: "TATER").uppercase()}" else "WHY TATER PICKED THIS",
                    color = TaterColors.OrangeBright,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                )
                Text(focused?.title ?: "Tater Picks", color = Color.White, fontSize = 31.sp, fontWeight = FontWeight.Bold, maxLines = 2)
                val message = focused?.reason ?: batch?.summary?.takeIf(String::isNotBlank) ?: batch?.picksBriefing.orEmpty()
                Text(message, color = Color.White.copy(alpha = .82f), fontSize = 16.sp, lineHeight = 23.sp, maxLines = 4)
                val speech = when (val value = state.speechState) {
                    TaterSpeechState.Idle -> "${state.recommendations.size} picks for you"
                    TaterSpeechState.Loading -> "Getting Tater's voice…"
                    TaterSpeechState.Speaking -> "Tater is speaking"
                    is TaterSpeechState.Failed -> value.message
                }
                Text(speech, color = TaterColors.SecondaryText, fontSize = 13.sp, maxLines = 1)
            }
            Image(painterResource(R.drawable.tater_hero_remote), null, Modifier.width(200.dp).fillMaxHeight(), contentScale = ContentScale.Fit)
        }
    }
}

@Composable
private fun PickCard(
    recommendation: RecommendationItem,
    viewModel: PlayerViewModel,
    onFocus: (Boolean) -> Unit,
    onClick: () -> Unit,
) {
    FocusCard(onClick, Modifier.fillMaxWidth(), 20.dp, onFocus) {
        Column(Modifier.padding(9.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
            Box {
                TaterArtwork(
                    recommendation.launch,
                    viewModel.wideArtworkUrl(recommendation.launch),
                    viewModel.token,
                    Modifier.fillMaxWidth().height(120.dp).clip(RoundedCornerShape(16.dp)),
                )
                Text(
                    "%02d".format(maxOf(1, recommendation.rank)),
                    color = Color.White,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.align(Alignment.TopEnd).padding(8.dp)
                        .background(TaterColors.Orange.copy(alpha = .9f), RoundedCornerShape(12.dp)).padding(horizontal = 8.dp, vertical = 4.dp),
                )
            }
            Text("TATER PICK  ·  ${(recommendation.mediaType ?: recommendation.launch.mediaType ?: "VIDEO").uppercase()}", color = TaterColors.OrangeBright, fontSize = 10.sp, fontWeight = FontWeight.Bold)
            Text(recommendation.title, color = Color.White, fontSize = 17.sp, fontWeight = FontWeight.Bold, maxLines = 1)
            Text(recommendation.reason, color = Color.White.copy(alpha = .7f), fontSize = 12.sp, maxLines = 2, overflow = TextOverflow.Ellipsis)
        }
    }
}

@Composable
private fun DestinationCard(title: String, glyph: String, onClick: () -> Unit) {
    FocusCard(onClick, Modifier.width(160.dp).height(146.dp), 20.dp) {
        Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
            Text(glyph, color = TaterColors.OrangeBright, fontSize = 34.sp, fontWeight = FontWeight.Bold)
            Text(title, color = Color.White, fontSize = 17.sp, fontWeight = FontWeight.Bold)
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
            .clip(shape)
            .background(TaterColors.Glass)
            .border(if (focused) 4.dp else 1.dp, border, shape)
            .padding(if (focused) (4.dp * (scale - 1f)) else 0.dp)
    ) { content() }
}

@Composable
private fun ProgressBar(percent: Float) {
    if (percent <= .5f) return
    Box(Modifier.fillMaxWidth().height(5.dp).background(Color.White.copy(alpha = .18f), RoundedCornerShape(3.dp))) {
        Box(Modifier.fillMaxWidth((percent / 100f).coerceIn(0f, 1f)).height(5.dp).background(TaterColors.Orange, RoundedCornerShape(3.dp)))
    }
}

@Composable
private fun StatePanel(title: String, message: String, loading: Boolean = false) {
    GlassSurface(Modifier.fillMaxWidth().height(210.dp), 28.dp) {
        Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
            Text(if (loading) "•••" else "✦", color = TaterColors.OrangeBright, fontSize = 30.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(10.dp))
            Text(title, color = Color.White, fontSize = 25.sp, fontWeight = FontWeight.Bold)
            Text(message, color = TaterColors.SecondaryText, fontSize = 15.sp, modifier = Modifier.padding(top = 8.dp))
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
